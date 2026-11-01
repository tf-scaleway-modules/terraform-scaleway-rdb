## MODIFIED Requirements

### Requirement: Required and optional inputs
The module SHALL expose 26 input variables, of which exactly `name` (string) and `node_type` (string) are required; every other input has a default. `engine` and `clone_from` have a `null` default and exactly one of them MUST be set (see the instances capability).

#### Scenario: Only required inputs set
- **WHEN** the caller sets only `name`, `node_type` and `engine`
- **THEN** the inputs are accepted, with no admin user, no database, no user, no privilege, no ACL rule, no read replica and no manual backup

#### Scenario: Missing required input
- **WHEN** the caller omits `name` or `node_type`
- **THEN** the configuration is rejected because the variable has no value

#### Scenario: Existing configuration
- **WHEN** a configuration written for v2 sets `organization_id` or `project_name`
- **THEN** the configuration is rejected because the variable is not declared

### Requirement: Input defaults
The optional inputs SHALL default to `null` (scalars and objects without a natural empty value), `false`, `true`, or an empty list, map or object as listed in the scenarios.

#### Scenario: Secure defaults
- **WHEN** the caller sets only the required inputs
- **THEN** encryption at rest is enabled, automated backups are enabled every 24 hours with 14 days of retention stored in another region, and the instance is not an HA cluster

#### Scenario: Null defaults
- **WHEN** the caller sets only the required inputs
- **THEN** `engine`, `clone_from`, `project_id`, `region`, `admin_user`, `admin_user_password`, `private_network` and `logs_policy` are `null`

#### Scenario: Other defaults
- **WHEN** the caller sets only the required inputs
- **THEN** `volume` is `{ type = "lssd" }`, `public_endpoint` and `allow_public_access` are `false`, `tags` is `[]`, and `settings`, `init_settings`, `user_passwords`, `databases`, `users`, `privileges`, `acl_rules`, `read_replicas` and `manual_backups` are `{}`

### Requirement: Input types
Each input SHALL have a declared type: strings, numbers and booleans for scalar settings, `list(string)` for `tags`, `map(string)` for `settings`, `init_settings` and `user_passwords`, and objects or maps of objects for `volume`, `backup`, `admin_user`, `private_network`, `logs_policy`, `databases`, `users`, `privileges`, `acl_rules`, `read_replicas` and `manual_backups`.

#### Scenario: Map-typed inputs
- **WHEN** the caller passes a map to `tags`
- **THEN** the configuration is rejected with a type error

#### Scenario: Wrong type
- **WHEN** the caller passes a non-numeric value to `backup.frequency_hours`
- **THEN** the configuration is rejected with a type error

### Requirement: Project identifier validation
`project_id`, when set, SHALL be a lowercase hexadecimal UUID (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).

#### Scenario: Invalid organization ID
- **WHEN** the caller sets `organization_id` as in v2
- **THEN** the configuration is rejected because the variable no longer exists

#### Scenario: Invalid project ID
- **WHEN** `project_id = "1234"`
- **THEN** the plan is rejected with "Project ID must be a valid UUID format."

#### Scenario: Invalid project name
- **WHEN** the caller sets `project_name` as in v2
- **THEN** the configuration is rejected because the variable no longer exists

#### Scenario: Valid single-letter project name
- **WHEN** `project_id` is a lowercase UUID
- **THEN** the input is accepted

### Requirement: Write-only password inputs
Every password SHALL be sent through the provider's write-only `password_wo` argument with a `password_wo_version`: the admin password as `admin_user_password` with `admin_user.password_version`, each user password as `user_passwords[<users key>]` with `users[*].password_version`. `password_version` defaults to `1`. No password is stored in state.

#### Scenario: Write-only admin password
- **WHEN** `admin_user = { name = "admin" }` and `admin_user_password` are set
- **THEN** the instance receives the value through `password_wo` with `password_wo_version = 1` and no `password`

#### Scenario: Changing a write-only password
- **WHEN** the caller increments `admin_user.password_version`
- **THEN** the new password is applied to the instance

## ADDED Requirements

### Requirement: Ephemeral password inputs
`admin_user_password` and `user_passwords` SHALL be declared `sensitive` and `ephemeral`, so no password appears in state or in the plan file. Every key of `user_passwords` MUST be a key of `users`.

#### Scenario: Ephemeral source
- **WHEN** the passwords come from ephemeral sources
- **THEN** the plan succeeds and the values appear neither in state nor in the plan file

#### Scenario: Unknown user key
- **WHEN** `user_passwords` has a key that is not in `users`
- **THEN** the plan is rejected with "user_passwords keys must be keys of users."

## MODIFIED Requirements

### Requirement: Password complexity
`admin_user_password` and every `user_passwords` value SHALL be 8 to 128 characters long and contain at least one uppercase letter, one lowercase letter, one digit and one special character from `!@#$%^&*()_+-=[]{}|;:,.<>?`.

#### Scenario: Admin password too short
- **WHEN** `admin_user_password = "Ab1!"`
- **THEN** the plan is rejected with "Password must be 8-128 characters with at least one uppercase, lowercase, digit, and special character."

#### Scenario: Admin write-only password without a digit
- **WHEN** `admin_user_password = "Password!!"`
- **THEN** the plan is rejected with the same message

#### Scenario: User password without a special character
- **WHEN** `user_passwords = { app = "Passw0rdOnly" }`
- **THEN** the plan is rejected with "User passwords must be 8-128 characters with at least one uppercase, lowercase, digit, and special character."

### Requirement: Outputs
The module SHALL expose 17 outputs: `project_id`, `instance_id`, `instance_region`, `instance_engine`, `instance_certificate`, `instance_load_balancer`, `instance_private_network`, `connection_host`, `connection_port`, `engine_type`, `engine_default_port`, `databases`, `users`, `privileges`, `acl_id`, `read_replicas` and `manual_backups`. Deprecated outputs, input echoes and password-bearing outputs do not exist.

#### Scenario: Output set
- **WHEN** the module is applied
- **THEN** the 17 outputs are available and `admin_password`, `connection_string`, `instance_endpoint_ip`, `instance_endpoint_port`, `instance_name`, `instance_node_type`, `instance_is_ha_cluster`, `encryption_at_rest_enabled`, `backup_enabled`, `database_ids`, `user_names` and `acl_rules` are not declared

#### Scenario: Secret and object outputs
- **WHEN** the module is applied
- **THEN** `project_id` is the project of the instance (also when the input was null) and `databases`, `users`, `privileges`, `acl_id`, `read_replicas` and `manual_backups` are available

### Requirement: Sensitive outputs
The output `instance_certificate` SHALL be marked `sensitive`; no other output is sensitive. The `users` output SHALL NOT include passwords.

#### Scenario: Sensitive marking
- **WHEN** the outputs are displayed by `tofu output`
- **THEN** `instance_certificate` is shown as sensitive

#### Scenario: No user password in outputs
- **WHEN** users are created
- **THEN** the `users` output contains only `id`, `name` and `is_admin` per user key

### Requirement: Endpoint outputs
`instance_load_balancer` SHALL be an object with `ip`, `port`, `name` and `hostname` and `instance_private_network` an object with `ip`, `port` and `hostname`, each `null` when the endpoint does not exist. `connection_host` and `connection_port` SHALL return the load balancer IP and port, or the private network IP and port when there is no load balancer, or `null`.

#### Scenario: No private network
- **WHEN** `private_network` is null
- **THEN** `instance_private_network` is `null` and `connection_host` is the load balancer IP

#### Scenario: Private-only instance
- **WHEN** `private_network` is set and `public_endpoint` is `false`
- **THEN** `instance_load_balancer` is `null` and `connection_host` is the private network IP

### Requirement: Engine helper outputs
`engine_type` SHALL be `"postgresql"` for engines starting with `PostgreSQL-` and `"mysql"` otherwise. `engine_default_port` SHALL be `5432` for PostgreSQL engines and `3306` otherwise. The engine is the `engine` input, or the engine of the instance when `engine` is null (clone).

#### Scenario: PostgreSQL engine
- **WHEN** `engine = "PostgreSQL-16"`
- **THEN** `engine_type` is `"postgresql"` and `engine_default_port` is `5432`

#### Scenario: MySQL engine
- **WHEN** `engine = "MySQL-8"`
- **THEN** `engine_type` is `"mysql"` and `engine_default_port` is `3306`

#### Scenario: Cloned engine
- **WHEN** `engine` is null and `clone_from` is set
- **THEN** `engine_type` and `engine_default_port` follow the engine the clone reports (known after apply)

## REMOVED Requirements

### Requirement: Ephemeral admin password
**Reason**: Replaced by "Ephemeral password inputs", which covers the admin and user passwords.
**Migration**: Pass the admin password as the ephemeral `admin_user_password`.

### Requirement: Admin password output
**Reason**: Always `null` once the only password form is write-only.
**Migration**: Read the password from your own secret source.

### Requirement: Connection string output
**Reason**: It embedded a password the module no longer holds.
**Migration**: Build the URL from `connection_host`, `connection_port` and your secret.

### Requirement: Setting echo outputs
**Reason**: Echoes of inputs and attributes the caller already has (`terraform-outputs`).
**Migration**: Use the inputs, or `instance_id`, `instance_engine`, `instance_region`, `instance_certificate`.
