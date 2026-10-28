## Why

While baselining the contract (`adopt-openspec`) ten gaps were noted: a public-access guard
that is easy to bypass, a secret input that is not ephemeral, a project lookup that fails when
no project is given, validations missing where the provider fails at apply, and descriptions
that promise behaviour the module does not have. This change fixes them without breaking
any configuration that works today (`terraform-versioning`, `quality-security`).

## What Changes

Decision per issue (all verified against the code, the provider schema and the provider
source of `scaleway/scaleway` 2.86):

| # | Issue | Decision | Breaking | Why |
|---|-------|----------|----------|-----|
| 1 | Guard only matches literal `0.0.0.0/0` | Code: new `check "acl_wide_ranges"` warning (prefix shorter than /8) unless `allow_public_access = true`; precondition unchanged | No | `::/0` is already rejected by the provider (the Scaleway API has no IPv6 ACL); rejecting `0.0.0.0/1` and similar would reject configs that work today, so a warning is the non-breaking alternative |
| 2 | `*_wo` secrets not `ephemeral` | Code: `admin_user_password_wo` becomes `ephemeral = true`. `users[*].password_wo` left, documented in `SECURITY.md` | No | A `map(object)` iterated with `for_each` cannot be ephemeral; splitting the secret out would add a new input (minor, speculative). Passing any value to an ephemeral input stays valid |
| 3 | `coalesce` errors with no project | Code: `locals.tf` resolves with `one()` so "none = provider default" works | No (fix) | Contradicted `variables.tf` and the precondition; also hid the precondition message when only `organization_id` was set |
| 4 | `admin_password` description says "auto-generated" | Doc fix in `outputs.tf` | No | The value is `admin_user_password` or the instance `password` attribute |
| 5 | `tags` says "all resources" | Doc fix | No | Only the instance carries tags |
| 6 | `private_network` neither `ip_net` nor `enable_ipam` | Code: validation requires `ip_net` or `enable_ipam = true`; description aligned | No (fix) | The provider fails at apply ("at least one of `ip_net` or `enable_ipam` (set to true) must be set"), so only already-failing input is rejected |
| 7 | `logs_policy` Cockpit text, `volume_size_in_gb` `bssd` | Doc fix | No | Not implemented / already rejected |
| 8a | Replica `private_network` has no CIDR check and no "one of" rule | Code: validations for CIDR `ip_net` and `ip_net` or `enable_ipam = true` | No (fix) | The provider rejects both at plan/apply. Mutual exclusion with `enable_ipam` NOT added: the provider ignores `enable_ipam` when `service_ip` is set (warning only), so such configs work |
| 8b | Privileges / manual backups not cross-checked with `users` / `databases` | Left; descriptions state the names are not cross-checked | n/a | Targets may legitimately live outside the module (admin user, `rdb` or pre-existing databases); a validation would be breaking and a check would warn on valid setups. A mismatch fails at apply with an API error |
| 9 | 585 GB manual backup limit only in text | Code: new `check "manual_backup_volume_size"` warning when `volume_size_in_gb > 585` and `manual_backups` is not empty | No | The limit comes from Scaleway documentation and cannot be confirmed from the provider; a warning avoids rejecting a working config. Local SSD sizes are unknown to the module |
| 10a | `backup_same_region` sent when backups are disabled | Code: `null` when `backup_enabled = false` | No (fix) | Consistent with schedule arguments; the attribute is optional+computed so no diff |
| 10b | `prevent_destroy = false` hard-coded | Left | n/a | `lifecycle.prevent_destroy` cannot reference variables (language limit); a hard `true` would block destroy for everyone |

Semver: **patch** (fixes, warnings, descriptions). No input or output is added, removed or
retyped; no default changes; no resource address changes.

Inputs/outputs whose meaning changes: `admin_user_password_wo` (now ephemeral),
`private_network` and `read_replicas[*].private_network` (new rejection of "neither"),
`backup_same_region` (not sent when backups are disabled), descriptions of `tags`,
`volume_size_in_gb`, `logs_policy`, `privileges`, `manual_backups`, `admin_password`.

State: no new secret-bearing input. `admin_user_password_wo` leaves the plan file as well.
`SECURITY.md` is created to list what lands in state (`admin_user_password`,
`users[*].password`, the `admin_password` and `connection_string` outputs, the non-ephemeral
`users[*].password_wo` variable value in plan files).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `network-access`: private network address validation requires one address mode; new wide ACL range warning.
- `instances`: project resolution works with no project input.
- `read-replicas`: replica private network address validation.
- `backups`: `backup_same_region` not sent when backups are disabled; manual backup size warning.
- `module-contract`: `admin_user_password_wo` is ephemeral.

## Impact

`main.tf`, `locals.tf`, `variables.tf`, `outputs.tf`, new `checks.tf`, new `tests/main.tftest.hcl`,
new `SECURITY.md`, `examples/complete` (admin password through `admin_user_password_wo`),
README generated block. Standards applied: `terraform-versioning`, `terraform-variables`,
`terraform-security`, `terraform-testing`, `quality-security`.
