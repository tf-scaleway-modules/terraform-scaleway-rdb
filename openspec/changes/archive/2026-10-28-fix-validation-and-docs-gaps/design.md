## Context

Ten noted gaps (see proposal). Constraints: no breaking change, `required_version >= 1.11.0`
and provider `~> 2.86` stay, no `provider {}`/`backend {}`.

## Decisions

- **Wide ACL warning (`checks.tf`)**: `check "acl_wide_ranges"` with condition
  `allow_public_access || no rule has a prefix shorter than the threshold`, prefix taken with
  `tonumber(split("/", ip)[1])` (the variable validation guarantees CIDR notation); threshold
  8 (the provider rejects IPv6 ACL rules itself). The precondition on
  `scaleway_rdb_instance.this` keeps its exact scope (`0.0.0.0/0`, which the check skips), so no working config is
  rejected. `terraform-security` asks for `check` on dangerous but legal configurations.
- **Manual backup size warning**: `check "manual_backup_volume_size"`, condition
  `length(manual_backups) == 0 || volume_size_in_gb == null || volume_size_in_gb <= 585`.
- **Ephemeral admin password**: `ephemeral = true` on `admin_user_password_wo`. It is only
  read by `password_wo` (write-only argument), by its own validation and by the instance
  precondition (ephemeral values are allowed there, verified with `tofu test`). Not in any
  output or local. `users` stays non-ephemeral: a `for_each` collection cannot be
  ephemeral or hold ephemeral attributes. Documented deviation in `SECURITY.md`.
- **Project resolution**: `var.project_id != null ? var.project_id : one(data.scaleway_account_project.this[*].id)`;
  `one()` of the empty splat is `null`, the provider default applies.
- **Private network**: extra validation `ip_net != null || enable_ipam == true`, same rule on
  replica `private_network` plus `can(cidrhost(ip_net, 0))`. Both-set stays accepted on
  replicas because the provider (`expandReadReplicaEndpointsSpecPrivateNetwork`) gives
  `service_ip` precedence.
- **backup_same_region**: `var.backup_enabled ? var.backup_same_region : null`. The
  provider attribute is optional+computed, so `null` produces no diff after apply; existing
  state with backups enabled is unchanged.

## Risks / migration

No resource address changes, no `moved` blocks. Plans of existing consumers: no change
except instances with `backup_enabled = false` (the argument is no longer set; computed
value is kept, no diff expected). New warnings appear for wide ACLs and large manual-backup
instances. A consumer who forwards a non-ephemeral value into `admin_user_password_wo` keeps working.
