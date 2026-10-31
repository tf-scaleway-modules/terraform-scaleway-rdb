# Design

## Context

Module pins `scaleway/scaleway ~> 2.86` (resolves to 2.89.0 today). Provider docs of the seven resources
(`rdb_instance`, `rdb_read_replica`, `rdb_database`, `rdb_user`, `rdb_privilege`, `rdb_acl`,
`rdb_database_backup`) were diffed between tags `v2.86.0` and `v2.89.0`: the **only** difference is
`clone_from` on `scaleway_rdb_instance` (plus the conflict note on `snapshot_id`). `data.scaleway_account_project`
gained `srn` in 2.87.0. Provider behaviour below was read in `internal/services/rdb/instance.go`,
`helpers.go` and `database_backup.go` at `v2.89.0`.

## Goals / Non-Goals

**Goals:** expose `clone_from` safely (no perpetual diff, no silent data or HA loss); close two small gaps found
in the gap analysis (`expires_at`, update timeout); keep every existing configuration valid.

**Non-Goals / Deferred (considered, not adopted):**

| Item | Since | Decision | Reason |
|------|-------|----------|--------|
| `snapshot_id` restore | < 2.86 | Deferred | Same inherited-value problems as `clone_from` and the module cannot create snapshots; own change if requested |
| Public + private endpoint (`load_balancer {}` next to `private_network`) | < 2.86 | Deferred | Real gap (module is private-only or public-only) but weakens network posture; needs its own input, spec and security review |
| Outputs `upgradable_versions`, `maintenances` | < 2.86 | Rejected | `terraform-outputs`: expose only what consumers wire; engine upgrade is an input change |
| `data.scaleway_account_project.srn` output | 2.87.0 | Deferred | Only known with name lookup; no consumer |
| Node type / engine validation via `scaleway_rdb_node_type`, `scaleway_rdb_database_engine` data sources | 2.84.0 | Rejected | An API call on every plan and credentials in the unit suite (`quality-efficiency`, `terraform-testing`); the regexes stay |
| Instance logs data sources | 2.84.0 | Rejected | Reads, not managed resources; the caller can use them directly |
| Provider actions (restart, renew certificate, purge logs, promote replica, apply maintenance) | 2.8x | Rejected | Imperative operations, not desired state; they need Terraform actions, which the supported `>= 1.11` range does not guarantee |
| Replica `hostname`, `endpoint_id`, `enable_ipam` in `read_replicas` output | < 2.86 | Deferred | No consumer asked; additive later (minor) |
| `rdb_privilege` `permission = "custom"` and `permission_status` | < 2.86 | Deferred | `custom` cannot be defined by the module (no argument to describe it) |
| Composite identity schema (2.83), `logs_policy` docs (2.84), restore keeps LB (2.83) | n/a | No action | Internal or already exposed (`logs_policy`) |

## Decisions

### D1. `clone_from` (provider 2.89.0)

Arguments used, with introducing version: `scaleway_rdb_instance.clone_from` (**2.89.0**), `load_balancer {}`
block, `node_type`, `name`, `tags`, `settings`, `logs_policy`, `private_network`, `is_ha_cluster`, `disable_backup`
(all < 2.86); `data.scaleway_rdb_instance` with `instance_id` (< 2.86).

Input: `variable "clone_from"` (`string`, default `null`, validation `^([a-z]{2}-[a-z]{3}/)?<uuid>$`). Passed as
`clone_from = var.clone_from`. `engine = var.engine` stays; `engine` is `Optional+Computed` and conflicts with
`clone_from` in the provider schema, so `null` is accepted.

Provider behaviour that shapes the guards (v2.89.0 `ResourceRdbInstanceCreate`):
- `CloneInstance` takes only `name` and `node_type`; HA, backup schedule, tags, endpoints are patched after, **only when set explicitly**.
- Not applied at clone: `volume_type` (schema default `lssd`), `volume_size_in_gb`, `project_id`, `encryption_at_rest`, `user_name`, `init_settings`.
  `user_name` is `Optional+Computed+ForceNew`, `init_settings` is `Optional+ForceNew` and read back from the API.
- The clone always gets a public LB; omitting `load_balancer {}` **deletes it** (`configureEndpointsAfterInheritedLB`), leaving an instance with no endpoint if no private network is configured.

Guards (`precondition` on `scaleway_rdb_instance.this`, the module's existing style; each with a rejected-input test):

| Guard | Why |
|-------|-----|
| exactly one of `engine`, `clone_from` | provider `ConflictsWith`; one is needed to know the engine |
| `clone_from != null` ⇒ `admin_user_name == null` | the module always sends `user_name`; a name that differs from the source's admin forces replacement on every plan; passwords follow through the existing admin precondition. `admin_password`/`connection_string` are `null` for a clone |
| `volume_type`, `volume_size_in_gb` (non-lssd), `encryption_at_rest`, `init_settings` equal the source | module defaults (`lssd`, `true`, `{}`) are always sent; if they differ from what the clone inherits the next plan shows a diff, a forced replacement (`init_settings`) or `disabling encryption_at_rest is not supported` |
| source HA ⇒ `is_ha_cluster = true` | module default `false` is always sent and would ask the provider to switch HA off on the clone (`UpgradeInstance enable_ha=false`); the clone provider path does not guard it |

Source values come from `data "scaleway_rdb_instance" "source"` (`count = var.clone_from != null ? 1 : 0`,
`instance_id = var.clone_from`, `region = var.region`), referenced as `one(data...source[*].x)`. One read, only in
clone mode (`quality-efficiency`). When the source is created in the same apply (`clone_from = module.x.instance_id`)
the read and the guards are deferred to apply time and run before the clone is created.
Overrides the provider supports in the same apply stay available because the module sends its values explicitly:
`is_ha_cluster = true`, `backup_enabled`/schedule (applied by the clone path when `disable_backup = false`), `tags`,
`settings` (`Optional+Computed`, `{}` is no diff), `logs_policy`, `private_network`. `project_id` is not applied by the
provider (clone stays in the source project); the module does not guard it: the description says so.

Endpoints: `dynamic "load_balancer" { for_each = var.clone_from != null && var.private_network == null ? [1] : [] }`.
Public clone keeps `load_balancer {}`; with `private_network` the provider creates the private endpoint and deletes the
LB, the same shape as a non-clone instance with `private_network`. Outputs keep reading `load_balancer[0]` /
`private_network[0]`. Non-clone plans have no `load_balancer` block, as today.

Engine helpers: `locals.engine = var.engine != null ? var.engine : scaleway_rdb_instance.this.engine`;
`is_postgresql`, `is_mysql` use it. With a literal `engine` nothing changes; for a clone they are known after apply.

Alternatives rejected: (a) derive `volume_*`/`encryption_at_rest`/HA from the source silently — hides what the module
sends and weakens the secure default without telling the caller (`quality-security`); (b) let the provider fail —
errors arrive at apply or as a permanent diff; (c) a separate `clone` object variable — a second shape for the same
arguments (`quality-simplicity`).

### D2. Provider floor `~> 2.89` (need-driven)

Only `clone_from` needs it. `expires_at`, the timeout and the docs do not. Per `terraform-providers` / `terraform-versioning`
the raised floor is a **major** bump (`v2.0.0`), stated in the CHANGELOG line and commit body with the reason. Alternative
considered: keep `~> 2.86` and ship minor without `clone_from` — rejected by the user's goal (adopt what 2.89 offers); the
cost is that consumers on a pinned lock file must run `init -upgrade`.

### D3. `manual_backups[*].expires_at` (present in 2.86.0 and 2.89.0)

`optional(string)`, default `null` (`terraform-variables`: `null` = server default, no invented default). The provider
reads it back as RFC 3339 UTC; to keep the second plan empty the validation accepts only `YYYY-MM-DDTHH:MM:SSZ`
(regex plus `can(timeadd(value, "0s"))`), because an offset form would be normalised by the API and diff forever.
The provider rejects removing an expiry once set; the description says so. Output gains `expires_at` (new map key = minor).

### D4. Update timeout 60m

`timeouts.update` 30m → 60m (the provider default; its docs: major/HA engine upgrades take longer and a timeout
leaves orphaned instances and a stale ID in state). Create/delete stay 30m. A timeout is client-side only: no diff, no state change.

### D5. Engine upgrade documentation (no code)

Changing `engine` already triggers a blue/green upgrade in the provider; the module has no guard and does not need one.
Add to the `engine` description and README: writes between snapshot and switch are lost; `scaleway_rdb_acl` (which uses
the instance ID) may need a second apply; never re-apply while an upgrade is running.

## Perpetual diff and state migration

| Change | Existing state | New plan |
|--------|----------------|----------|
| `clone_from` default `null` | none | no diff (`Optional`, null = unset) |
| `engine` optional | engine unchanged | no diff |
| update timeout 60m | not in the resource attributes | no diff |
| `expires_at` default `null` | `null`/absent for existing backups | no diff; `expires_at` is `Optional` non-computed and the API returns `null` when unset |
| provider 2.86 → 2.89 | `SchemaVersion` unchanged (0) | in-place; verify with a plan against an existing state before release |
| `clone_from` set on an existing instance | | **forced replacement** (`ForceNew`); description carries the warning, as `is_ha_cluster` does |

No resource address changes, so no `moved` block. Clone mode second plan is empty because every argument the provider
does not apply at clone time is constrained to equal the source (guards above), and the rest is applied or computed.
No `provider {}`/`backend {}`, no CLI calls.

## Risks / Trade-offs

- [Guards read the source through a data source: a plan-time read needs the source to exist and credentials] → only in clone mode; when the source is created in the same apply the read is deferred.
- [HA guard rests on reading provider code, not on a live test] → confirm in the apply phase; if the provider handles `enable_ha=false` safely, relax the guard to a `check` warning.
- [`init_settings` of a clone: whether the API returns the source's init settings] → the guard compares with the data source value, correct either way; confirm the shape with a unit test override and, if allowed, one real clone.
- [Major bump forces consumers to upgrade the provider] → stated in CHANGELOG and README upgrade notes; no input removed.
- [A clone's users and databases already exist] → `users`/`databases` entries with the same names fail at apply with an API conflict; the description says to declare only new ones. Not checkable at plan time without listing users.
- [No real Scaleway apply in the unit suite] → the apply phase runs the unit tests with `mock_provider` only; a real clone apply is a manual step the user must approve.

## Implementation notes

- Tests override the whole `data.scaleway_rdb_instance.source` (an `override_data` target cannot carry an instance key such as `[0]`).
- With the mock provider the computed `engine` of a cloned instance is a random string at plan time, so the clone test asserts on `var.engine == null` and the `engine_type` follow-through is tested with `override_resource` after apply.
- `examples/complete/versions.tf` provider floor raised to `>= 2.89` (the opt-in clone needs it); `examples/minimal` unchanged.
