# Proposal

## Why

v2.0.0 raised the provider floor to `~> 2.89` for `clone_from` only. The input contract still carries what
accumulated before: two project inputs plus a data source, two admin password forms, 32 flat inputs, tags as a
map converted by hand, deprecated and echo outputs, and a secret-bearing `connection_string`. A major release is
allowed, so this change gap-checks every managed resource against the 2.89.0 schema, revisits the deferred
items of `update-provider-2-89`, removes the legacy shapes and adds the one missing endpoint capability
(public + private). See `design.md` for the schema evidence.

## What Changes

### Adopted features

| Feature | Resource / argument | Provider | Why |
|---|---|---|---|
| Public endpoint next to a private network (new `public_endpoint`, default `false`) | `scaleway_rdb_instance.load_balancer {}` with `private_network` | < 2.86 (was deferred) | Module is public-only or private-only today; hybrid access (private apps + operator access through ACL) is common. Opt-in keeps the private-only posture |
| Ephemeral per-user passwords (`user_passwords`) | `scaleway_rdb_user.password_wo` + `password_wo_version` | < 2.86 (module used it inside `users`) | `users` is iterated with `for_each` so `password_wo` could not be ephemeral; a separate ephemeral map keyed like `users` keeps every password out of state **and** plan |
| Replica `hostname` in `read_replicas` output | `scaleway_rdb_read_replica.{direct_access,private_network}.hostname` | < 2.86 (was deferred) | TLS clients connect by hostname; the attribute is already read |
| `connection_host`/`connection_port` fall back to the private endpoint | `private_network[0].ip/port` | < 2.86 | Private-only instances returned `null` |

### Breaking changes (consumer edit)

| Change | Consumer edit |
|---|---|
| `organization_id`, `project_name` removed; `data.scaleway_account_project` removed | Use `project_id` (`null` = provider default project) |
| `admin_user_name`, `admin_user_password`, `admin_user_password_wo`, `admin_user_password_wo_version` replaced by `admin_user = { name, password_version }` + ephemeral `admin_user_password` | `admin_user = { name = "admin" }`, `admin_user_password = <ephemeral value>`; was `admin_user_password` (stored in state): the first apply updates the instance in place to the write-only form |
| `users[*].password`, `password_wo`, `password_wo_version` removed | `users[k] = { name, is_admin, password_version }` and `user_passwords = { k = <ephemeral value> }` |
| `volume_type`, `volume_size_in_gb` → `volume = { type, size_in_gb }` | `volume = { type = "sbs_5k", size_in_gb = 100 }` |
| `backup_enabled`, `backup_schedule_frequency`, `backup_schedule_retention`, `backup_same_region` → `backup = { enabled, frequency_hours, retention_days, same_region }` | rename the keys into one object |
| `tags` `map(string)` → `list(string)` | `tags = ["environment=production"]` (`[for k, v in old : "${k}=${v}"]`) |
| Outputs removed: `admin_password`, `connection_string` (always null with write-only passwords), `instance_endpoint_ip`, `instance_endpoint_port` (deprecated), `instance_name`, `instance_node_type`, `instance_is_ha_cluster`, `encryption_at_rest_enabled`, `backup_enabled` (input echoes), `database_ids`, `user_names`, `acl_rules` (subsets of `databases`, `users`, input) | Use `connection_host`/`connection_port`, `databases[k].id`, `users[k].name`, your own inputs |
| `engine_type` never returns `"unknown"` | none (engines are validated to PostgreSQL/MySQL) |

### Simplifications

| Item | Result |
|---|---|
| `locals.tf`: project resolution, tags conversion, `is_mysql`, `database_ids`, `user_info` | removed or inlined |
| `lifecycle { prevent_destroy = false }` and its comment | removed (the default) |
| Project precondition, dual admin password precondition | removed with their inputs |
| 12 outputs (deprecated, echoes, always-null secrets, subsets) | removed; 17 remain |
| Flat prefixed inputs (`volume_*`, `backup_*`, `admin_user_*`) | three objects with `optional()` defaults |

### Deferred / Rejected

| Item | Since | Decision | Reason |
|---|---|---|---|
| Maintenance window input | n/a | Rejected | No argument on any 2.89.0 RDB resource (`maintenances` is computed only) |
| `scaleway_rdb_snapshot` resource, `snapshot_id` restore | < 2.86 | Rejected | `manual_backups` cover logical backups; `clone_from` is the copy path; `snapshot_id` has the inherited-value problems already guarded for clones (`quality-simplicity`) |
| `databases`/`users` as sets or lists | n/a | Rejected | Changes every resource address; `moved` blocks cannot map caller keys |
| `privileges` referencing `users`/`databases` keys | n/a | Rejected | Targets may live outside the module (admin user, existing databases) |
| `zone` input, private network `zone` | 2.89.0 schema | Rejected | RDB is regional; `zone` is optional+computed and server-chosen |
| Outputs `upgradable_versions`, `maintenances`; node-type/engine data sources; instance log data sources; provider actions | < 2.86 / 2.84+ | Rejected (unchanged) | Same reasons as `update-provider-2-89` |
| `permission = "custom"`, `permission_status` | < 2.86 | Rejected | Module cannot define a custom permission |
| `srn` of `scaleway_iam_api_key` (2.90.0) | 2.90.0 | Rejected | IAM, not RDB; not on the registries yet |
| Exposing `effective_permission`, `download_url` | < 2.86 | Rejected | No consumer; additive later |

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `module-contract`: input/output counts and defaults, types, project IDs, write-only password handling, outputs.
- `instances`: project resolution, `volume`, `admin_user`, `tags`, clone guards on `volume`.
- `databases-and-users`: users without password fields, `user_passwords`, trimmed outputs.
- `network-access`: `public_endpoint`, clone endpoint rule.
- `backups`: `backup` object, size warning on `volume.size_in_gb`.
- `read-replicas`: replica `hostname`.

## Semver

**Major** (`terraform-versioning`): inputs and outputs removed, types changed. Next tag `v3.0.0` (last `v2.0.0`).
Inputs whose type, default or meaning changes: `tags` (map → list), `project_id` (now the only project input),
`admin_user_password` (was the state-stored password, now ephemeral write-only), `users` (password fields moved),
new `admin_user`, `volume`, `backup`, `user_passwords`, `public_endpoint`; removed `organization_id`,
`project_name`, `admin_user_name`, `admin_user_password_wo`, `admin_user_password_wo_version`, `volume_type`,
`volume_size_in_gb`, `backup_enabled`, `backup_schedule_frequency`, `backup_schedule_retention`,
`backup_same_region`. Inputs 32 → 26. Outputs 29 → 17 (12 removed, none added; `connection_host`/`connection_port`
and `read_replicas` change meaning). `required_version` stays `>= 1.11.0` (write-only, ephemeral variables);
provider floor stays `~> 2.89`.

## State

No secret lands in state any more: admin and user passwords are write-only (`terraform-security`). Existing
state keeps the old `password` value until the first apply replaces it in place. The `users` map is no longer
secret-bearing; `user_passwords` is `sensitive` + `ephemeral`. No resource address changes: no `moved` block, no
replacement (to be confirmed by a plan against an existing state, see tasks).

## Impact

`variables.tf`, `main.tf`, `locals.tf`, `outputs.tf`, `data.tf`, `checks.tf`, `tests/main.tftest.hcl`,
`examples/minimal`, `examples/complete`, `README.md` (generated block + "Upgrading from v2 to v3"),
`SECURITY.md`, `AGENTS.md`/`openspec/config.yaml` module-specific lines (password and project wording), specs of the
six capabilities. Standards applied: `terraform-versioning`, `terraform-providers`, `terraform-variables`,
`terraform-outputs`, `terraform-security`, `terraform-testing`, `quality-simplicity`, `quality-efficiency`,
`quality-security`, `quality-production-readiness`.
