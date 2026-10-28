## MODIFIED Requirements

### Requirement: Write-only password inputs
The module SHALL accept the admin password as `admin_user_password` or as the write-only `admin_user_password_wo` with `admin_user_password_wo_version`, and each user password as `users[*].password` or write-only `users[*].password_wo` with `users[*].password_wo_version`. The `*_wo` values are passed to the provider's `password_wo` argument.

#### Scenario: Write-only admin password
- **WHEN** `admin_user_name` is set with `admin_user_password_wo` and `admin_user_password_wo_version = 1`
- **THEN** the instance receives the value through `password_wo` and `password_wo_version = 1`, and the module's `admin_password` and `connection_string` outputs are `null`

#### Scenario: Changing a write-only password
- **WHEN** the caller changes `admin_user_password_wo_version`
- **THEN** the new write-only password is applied to the instance

## ADDED Requirements

### Requirement: Ephemeral admin password
`admin_user_password_wo` SHALL be declared `sensitive` and `ephemeral`. `users[*].password_wo` cannot be ephemeral because `users` is iterated with `for_each`; `SECURITY.md` documents that limit.

#### Scenario: Ephemeral admin password
- **WHEN** `admin_user_password_wo` is supplied from an ephemeral source
- **THEN** the plan succeeds and the value appears neither in state nor in the plan file
