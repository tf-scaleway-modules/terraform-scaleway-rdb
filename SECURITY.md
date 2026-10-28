# Security

## What lands in state

| Item | In state | In plan file | Mitigation |
|------|----------|--------------|------------|
| `admin_user_password_wo` | No (write-only) | No (ephemeral input) | Preferred form; bump `admin_user_password_wo_version` to rotate |
| `users[*].password_wo` | No (write-only) | Yes: the `users` map is iterated with `for_each`, so it cannot be ephemeral | Treat plan files as secrets; do not publish them |
| `admin_user_password` | Yes (`password` argument) | Yes | Use `admin_user_password_wo` instead; encrypt the state backend |
| `users[*].password` | Yes (`password` argument) | Yes | Use `users[*].password_wo` instead; encrypt the state backend |
| `admin_password` and `connection_string` outputs | Yes (sensitive, only when `admin_user_password` is set) | Yes | Both are `null` with the write-only form |
| `clone_from`, `manual_backups[*].expires_at` | Yes (instance ID, timestamp; not secret) | Yes | None needed; a clone takes no password (`admin_user_name` and the admin passwords must be null) |
| `instance_certificate` output | Yes (sensitive, public certificate of the instance) | Yes | None needed beyond sensitive handling |

State must be stored encrypted with restricted access. `*.tfstate*`, `*.tfvars` and plan files must never be committed.

## Network exposure

An ACL rule `0.0.0.0/0` is rejected unless `allow_public_access = true`. Other very wide
IPv4 ranges (prefix shorter than /8, such as `0.0.0.0/1`) only raise the
`acl_wide_ranges` plan-time warning: review it in the plan output. Prefer a private network.
