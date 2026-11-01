# Design

## Context

Baseline: v2.0.0, provider `~> 2.89` (2.89.0 is the newest on the registries; v2.90.0 is tagged on GitHub without
binaries and adds only a computed `srn` on the ephemeral `scaleway_iam_api_key`, not used here). The 2.89.0 schema
(`scaleway_rdb_{instance,database,user,privilege,acl,read_replica,database_backup}` and the instance data source)
was compared with `main.tf`. Result: every argument the module needs exists; no RDB resource has a maintenance
window argument (`maintenances` is computed only); `scaleway_rdb_snapshot` exists but is rejected (below).
Write-only `password_wo` (+ `password_wo_version`) exists on **both** `scaleway_rdb_instance` and
`scaleway_rdb_user`, so the plain `password` path can go everywhere. `required_version` stays `>= 1.11.0`
(write-only arguments, ephemeral variables); the provider floor stays `~> 2.89` (`clone_from`).

## Goals / Non-Goals

**Goals:** one way to do each thing (project, passwords, tags); inputs grouped into objects; no secret in state or
plan; outputs reduced to what consumers wire; hybrid public+private endpoint; empty second plan for unchanged
infrastructure and no address change.
**Non-Goals:** new resources (none needed), `provider {}`/`backend {}`, CLI calls.

## Decisions

### D1. Project: `project_id` only
Remove `organization_id`, `project_name`, `data.scaleway_account_project.this`, `locals.project_id` and the project
precondition. `project_id = var.project_id` (null = provider default; the attribute is optional+computed so no diff).
Output `project_id` = `scaleway_rdb_instance.this.project_id`, so it is known even when the input is null.
Alternative kept out: keeping name lookup for convenience — rejected, a second path for one value, the cross-module convention
is `project_id` (`quality-simplicity`). IAM-style `organization_id` is not needed by any RDB resource.

### D2. Passwords: write-only only, ephemeral for admin and users
Arguments: `scaleway_rdb_instance.password_wo`/`password_wo_version`, `scaleway_rdb_user.password_wo`/`password_wo_version`
(both < 2.86, write-only needs OpenTofu/Terraform >= 1.11). Verified in the schema: both are `write_only`, `password`
is `sensitive` and stored in state.
- `admin_user = object({ name = string, password_version = optional(number, 1) })` (default `null`) and
  `admin_user_password` (`string`, `sensitive`, `ephemeral`, default `null`). Instance: `user_name = try(var.admin_user.name, null)`,
  `password_wo = var.admin_user_password`, `password_wo_version = try(var.admin_user.password_version, null)`.
- Users: `users` stays a map keyed by caller key (addresses unchanged) with `password_version`; the secrets move to
  `user_passwords = map(string)` (`sensitive`, `ephemeral`), read as `var.user_passwords[each.key]`. An ephemeral value may
  be used inside a `for_each` resource body when the iterated collection (`var.users`) is not ephemeral, so the v2
  limit ("a map iterated with for_each cannot be ephemeral", `SECURITY.md`) disappears.
- Guards: `user_passwords` keys ⊆ `users` keys (variable validation, ephemeral variable may read the non-ephemeral
  `users`); every user has a password (precondition on `scaleway_rdb_user.this`); admin pair set together or neither
  (instance precondition); clone mode forbids both. Complexity regex unchanged, applied to `admin_user_password`
  and `values(user_passwords)`.
- Outputs `admin_password` and `connection_string` are removed: with write-only values they are always `null`.
Alternatives: keep the plain form for non-ephemeral callers — rejected, it stores the secret in state
(`terraform-security`); keep `password_wo` inside `users` — rejected, stays in the plan file.
Risk: a precondition reading an ephemeral variable must be accepted by OpenTofu 1.11.6 (v2 already does it for the
admin password). Confirmed with `tofu test` (run `user_without_password_rejected`): the per-user precondition on
`scaleway_rdb_user.this` is accepted, so the `validation` fallback is not needed.

### D3. Grouped inputs
| Object | Replaces | Defaults |
|---|---|---|
| `volume` | `volume_type`, `volume_size_in_gb` | `{ type = "lssd" }` |
| `backup` | `backup_enabled`, `backup_schedule_frequency`, `backup_schedule_retention`, `backup_same_region` | `{ enabled = true, frequency_hours = 24, retention_days = 14, same_region = false }` |
| `admin_user` | `admin_user_name` + version | `null` |

`variable "volume" { type = object({ type = optional(string, "lssd"), size_in_gb = optional(number) }); default = {} }`,
`backup` likewise (`default = {}`), so defaults and validation messages keep their v2 values. Sent values are identical
to v2 (`disable_backup = !var.backup.enabled`, schedule `null` when disabled), so no diff. `is_ha_cluster`,
`encryption_at_rest` stay flat booleans (one value each, `terraform-variables`). `logs_policy`, `private_network`
objects unchanged.

### D4. Tags: `list(string)`
`tags = distinct(var.tags)` straight to the instance (the only taggable RDB resource the module manages). Same
`"key=value"` strings as v2's converted map, so existing tags show no diff when the consumer converts the map.
No per-item tags exist, nothing to merge. Removes `locals.tags_list`.

### D5. Public endpoint next to a private network (`public_endpoint`)
Argument: `scaleway_rdb_instance.load_balancer {}` alongside `private_network` (both max 1 block, < 2.86). New
`public_endpoint` (`bool`, default `false`); precondition: it requires `private_network` (without one the instance
is always public). Block condition:
`for_each = (var.clone_from != null && var.private_network == null) || var.public_endpoint ? [1] : []`.
Default `false` keeps v2 behaviour for every existing instance (no `load_balancer` block for non-clones, so no diff).
Adding it to a private instance is an in-place endpoint creation by the provider. Security: opt-in, private-only
remains the default; the ACL and `allow_public_access` guards apply to the public side unchanged.
Output `connection_host`/`connection_port` = LB ip/port, else private network ip/port (`try(lb[0].x, pn[0].x, null)`;
a `coalesce` inside `try` returned `null` for private-only instances because `lb[0]` fails first).
Rejected alternative: `public_endpoint = null/true/false` tri-state — more states than the provider has.

### D6. Outputs
Removed (`terraform-outputs`: no echoes, no deprecated, no secrets): `admin_password`, `connection_string`,
`instance_endpoint_ip`, `instance_endpoint_port` (the provider attributes `endpoint_ip`/`endpoint_port` are
deprecated), `instance_name`, `instance_node_type`, `instance_is_ha_cluster`, `encryption_at_rest_enabled`,
`backup_enabled`, `database_ids`, `user_names`, `acl_rules`. `instance_region` stays (computed when the input is null).
`read_replicas[*].{direct_access,private_network}` gain `hostname` (attribute exists on both blocks). `engine_type` drops the
`unknown` branch (validation guarantees PostgreSQL or MySQL; for a clone the engine is the source's).
`locals.tf` shrinks to `engine`, `is_postgresql`; map outputs are built inline.

### D7. Other cleanups
`lifecycle { prevent_destroy = false }` removed (the default; the comment documented a language limit already stated in
`fix-validation-and-docs-gaps`). Replica `private_network`, ACL, `manual_backups.expires_at`, clone guards, update
timeout 60m, checks: unchanged except for the renamed `volume`/`admin_user` references and messages
(`volume.type`, `volume.size_in_gb`, `admin_user`).

### D8. Revisited deferred/rejected items
| Item | Decision |
|---|---|
| Public + private endpoint (deferred) | Adopted, D5 |
| Replica `hostname` (deferred) | Adopted; `endpoint_id`, `enable_ipam` still no consumer |
| `snapshot_id`, `scaleway_rdb_snapshot` (deferred) | Rejected: `manual_backups` + `clone_from`; snapshot restore repeats the clone's inherited-value traps |
| `srn` of the project data source (deferred) | Moot: data source removed |
| `permission = "custom"` (deferred) | Rejected: the module has no way to define it |
| Maintenance window | Rejected: no argument in 2.89.0 |
| `zone` | Rejected: RDB instance has only `region`; private network `zone` is computed by the server |
| `upgradable_versions`, `maintenances`, data sources, actions | Rejected as in `update-provider-2-89` |

## Perpetual diff and state migration

| Change | Existing state | Plan after upgrade |
|---|---|---|
| Provider floor | unchanged (`~> 2.89`) | none |
| Project removed | `project_id` known in state | none if the consumer passes the same ID; otherwise (was null) none |
| Tags list | tags already `key=value` strings | none when converted as documented |
| `volume`, `backup` objects | same values sent | none |
| Admin password plain → `password_wo` | `password` stored | in-place update of the instance: `password` becomes null, `password_wo_version` set. Not a replacement (`password` has no `ForceNew`); confirm on a real instance |
| User password plain → `password_wo` | `password` stored | in-place update of each user, same check |
| `load_balancer` | no block | none with `public_endpoint = false` |
| Outputs removed | n/a | consumers referencing them fail at plan: README upgrade table |

No resource address changes (`this`, `for_each` keys kept), so **no `moved` block and no forced replacement**; the
second plan after the first apply must be empty. If the real-account check shows a replacement for the instance or a
user, stop and add a documented migration instead of shipping.

## Risks / Trade-offs

- [Consumers lose `connection_string` and plain passwords] → README "Upgrading from v2 to v3" table with the edit for each.
- [Rotating a write-only password needs a `password_version` bump] → documented in the input descriptions; default `1`.
- [Ephemeral precondition support] → see D2 fallback.
- [`public_endpoint = true` widens exposure] → opt-in, off by default, ACL rules required by the same guards.

## Implementation notes

- `tests/main.tftest.hcl` (a type error such as `tags` given as a map, or an undeclared input such as `organization_id`,
  cannot be matched by `expect_failures`, so those two rejections are not unit-tested; the absence of the 12 removed
  outputs is checked by counting 17 `output` blocks): drop the `data.scaleway_account_project` override and the project-lookup runs; pass
  `admin_user_password` and `user_passwords` as plain test variables (test variables are allowed for ephemeral inputs).
- `examples/minimal` uses the ephemeral admin password; `examples/complete` shows `user_passwords`, `volume`, `backup`,
  `public_endpoint` with a private network (variable-gated), and the clone.
