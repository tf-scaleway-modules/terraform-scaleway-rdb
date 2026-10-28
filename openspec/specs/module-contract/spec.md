# module-contract Specification

## Purpose
Supported tool and provider versions, input and output contract and write-only password handling of the module.

## Requirements

### Requirement: Supported tool and provider versions
The module SHALL declare `required_version = ">= 1.11.0"` and the provider `scaleway/scaleway` with version constraint `~> 2.86` in `versions.tf`.

#### Scenario: Older OpenTofu or Terraform
- **WHEN** the module is initialised with OpenTofu or Terraform older than 1.11.0
- **THEN** initialisation fails on the `required_version` constraint

#### Scenario: Provider constraint
- **WHEN** the module is initialised
- **THEN** the `scaleway/scaleway` provider is selected within `~> 2.86`

### Requirement: No provider or backend configuration
The module SHALL NOT contain a `provider` block or a `backend` block; the caller configures the Scaleway provider (credentials, default region, default project).

#### Scenario: Caller owns the provider
- **WHEN** a caller uses the module
- **THEN** the Scaleway provider configuration comes from the caller, and the module only declares `required_providers`

### Requirement: Required and optional inputs
The module SHALL expose 31 input variables, of which exactly `name` (string), `engine` (string) and `node_type` (string) are required; every other input has a default.

#### Scenario: Only required inputs set
- **WHEN** the caller sets only `name`, `engine` and `node_type`
- **THEN** the inputs are accepted, with no admin user, no database, no user, no privilege, no ACL rule, no read replica and no manual backup

#### Scenario: Missing required input
- **WHEN** the caller omits `name`, `engine` or `node_type`
- **THEN** the configuration is rejected because the variable has no value

### Requirement: Input defaults
The optional inputs SHALL default to `null` (scalar and object inputs without a natural empty value), `false`, `true`, a number or an empty map as listed in the scenarios.

#### Scenario: Secure defaults
- **WHEN** the caller sets only the required inputs
- **THEN** encryption at rest is enabled, automated backups are enabled every 24 hours with 14 days of retention, and the instance is not an HA cluster

#### Scenario: Null defaults
- **WHEN** the caller sets only the required inputs
- **THEN** `organization_id`, `project_name`, `project_id`, `region`, `volume_size_in_gb`, `admin_user_name`, `admin_user_password`, `admin_user_password_wo`, `admin_user_password_wo_version`, `private_network` and `logs_policy` are `null`

#### Scenario: Other defaults
- **WHEN** the caller sets only the required inputs
- **THEN** `volume_type` is `"lssd"`, `backup_same_region` and `allow_public_access` are `false`, and `settings`, `init_settings`, `tags`, `databases`, `users`, `privileges`, `acl_rules`, `read_replicas` and `manual_backups` are `{}`

### Requirement: Input types
Each input SHALL have a declared type: strings, numbers and booleans for scalar settings, `map(string)` for `settings`, `init_settings` and `tags`, and objects or maps of objects for `private_network`, `logs_policy`, `databases`, `users`, `privileges`, `acl_rules`, `read_replicas` and `manual_backups`.

#### Scenario: Map-typed inputs
- **WHEN** the caller passes a list to `tags`
- **THEN** the configuration is rejected with a type error

#### Scenario: Wrong type
- **WHEN** the caller passes a non-numeric value to `backup_schedule_frequency`
- **THEN** the configuration is rejected with a type error

### Requirement: Project identifier validation
`organization_id` and `project_id`, when set, SHALL be lowercase hexadecimal UUIDs (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`). `project_name`, when set, SHALL start with a lowercase letter, contain only lowercase letters, digits and hyphens, end with a letter or digit, and be 1 to 63 characters long.

#### Scenario: Invalid organization ID
- **WHEN** `organization_id = "not-a-uuid"`
- **THEN** the plan is rejected with "Organization ID must be a valid UUID format."

#### Scenario: Invalid project ID
- **WHEN** `project_id = "1234"`
- **THEN** the plan is rejected with "Project ID must be a valid UUID format."

#### Scenario: Invalid project name
- **WHEN** `project_name = "My_Project"`
- **THEN** the plan is rejected with "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 1-63 characters."

#### Scenario: Valid single-letter project name
- **WHEN** `project_name = "a"`
- **THEN** the input is accepted

### Requirement: Write-only password inputs
The module SHALL accept the admin password as `admin_user_password` or as the write-only `admin_user_password_wo` with `admin_user_password_wo_version`, and each user password as `users[*].password` or write-only `users[*].password_wo` with `users[*].password_wo_version`. The `*_wo` values are passed to the provider's `password_wo` argument.

#### Scenario: Write-only admin password
- **WHEN** `admin_user_name` is set with `admin_user_password_wo` and `admin_user_password_wo_version = 1`
- **THEN** the instance receives the value through `password_wo` and `password_wo_version = 1`, and the module's `admin_password` and `connection_string` outputs are `null`

#### Scenario: Changing a write-only password
- **WHEN** the caller changes `admin_user_password_wo_version`
- **THEN** the new write-only password is applied to the instance

### Requirement: Ephemeral admin password
`admin_user_password_wo` SHALL be declared `sensitive` and `ephemeral`. `users[*].password_wo` cannot be ephemeral because `users` is iterated with `for_each`; `SECURITY.md` documents that limit.

#### Scenario: Ephemeral admin password
- **WHEN** `admin_user_password_wo` is supplied from an ephemeral source
- **THEN** the plan succeeds and the value appears neither in state nor in the plan file

### Requirement: Password complexity
`admin_user_password`, `admin_user_password_wo` and every `users[*].password` or `users[*].password_wo` that is set SHALL be 8 to 128 characters long and contain at least one uppercase letter, one lowercase letter, one digit and one special character from `!@#$%^&*()_+-=[]{}|;:,.<>?`.

#### Scenario: Admin password too short
- **WHEN** `admin_user_password = "Ab1!"`
- **THEN** the plan is rejected with "Password must be 8-128 characters with at least one uppercase, lowercase, digit, and special character."

#### Scenario: Admin write-only password without a digit
- **WHEN** `admin_user_password_wo = "Password!!"`
- **THEN** the plan is rejected with the same message

#### Scenario: User password without a special character
- **WHEN** a user is declared with `password = "Passw0rdOnly"`
- **THEN** the plan is rejected with "User passwords must be 8-128 characters with at least one uppercase, lowercase, digit, and special character."

### Requirement: Outputs
The module SHALL expose 29 outputs, grouped as instance and endpoint outputs, engine helpers, `admin_password`, `connection_string`, database, user, privilege, ACL, read replica and manual backup maps, and the `encryption_at_rest_enabled` and `backup_enabled` echoes.

#### Scenario: Output set
- **WHEN** the module is applied
- **THEN** `project_id`, `instance_id`, `instance_name`, `instance_endpoint_ip`, `instance_endpoint_port`, `instance_load_balancer`, `instance_private_network`, `instance_certificate`, `instance_engine`, `engine_type`, `engine_default_port`, `instance_is_ha_cluster`, `instance_node_type` and `instance_region` are available

#### Scenario: Secret and object outputs
- **WHEN** the module is applied
- **THEN** `admin_password`, `connection_string`, `connection_host`, `connection_port`, `database_ids`, `databases`, `user_names`, `users`, `privileges`, `acl_id`, `acl_rules`, `read_replicas`, `manual_backups`, `encryption_at_rest_enabled` and `backup_enabled` are available

### Requirement: Sensitive outputs
The outputs `instance_certificate`, `admin_password` and `connection_string` SHALL be marked `sensitive`; no other output is sensitive. The `users` and `user_names` outputs SHALL NOT include passwords.

#### Scenario: Sensitive marking
- **WHEN** the outputs are displayed by `tofu output`
- **THEN** `instance_certificate`, `admin_password` and `connection_string` are shown as sensitive

#### Scenario: No user password in outputs
- **WHEN** users are created
- **THEN** the `users` output contains only `id`, `name` and `is_admin` per user key and `user_names` contains only the names

### Requirement: Admin password output
The `admin_password` output SHALL return `admin_user_password` when it is set, otherwise the `password` attribute of the instance when available, otherwise `null`.

#### Scenario: Password provided
- **WHEN** `admin_user_password` is set
- **THEN** `admin_password` equals that value

#### Scenario: Write-only password provided
- **WHEN** only `admin_user_password_wo` is set
- **THEN** `admin_password` does not return the write-only value

### Requirement: Connection string output
The `connection_string` output SHALL be `null` unless both `admin_user_name` and `admin_user_password` are set. For PostgreSQL engines it SHALL be `postgres://<user>:<password>@<host>:<port>/postgres?sslmode=require`; for MySQL engines it SHALL be `mysql://<user>:<password>@<host>:<port>`. The host and port come from the instance load balancer endpoint, falling back to an empty host and port `0` when that endpoint is unavailable.

#### Scenario: PostgreSQL with admin password
- **WHEN** `engine = "PostgreSQL-15"`, `admin_user_name` and `admin_user_password` are set
- **THEN** the output is a `postgres://` URL ending in `/postgres?sslmode=require`

#### Scenario: MySQL with admin password
- **WHEN** `engine = "MySQL-8"`, `admin_user_name` and `admin_user_password` are set
- **THEN** the output is a `mysql://` URL without a database name

#### Scenario: No admin user or write-only password
- **WHEN** `admin_user_name` is null, or the admin password is given as `admin_user_password_wo`
- **THEN** `connection_string` is `null`

### Requirement: Endpoint outputs
`connection_host` and `connection_port` SHALL return the IP and port of the instance load balancer endpoint, or `null` when none exists. `instance_endpoint_ip` and `instance_endpoint_port` SHALL return the same values and are described as deprecated. `instance_load_balancer` SHALL be an object with `ip`, `port`, `name` and `hostname`, and `instance_private_network` an object with `ip`, `port` and `hostname` (first private network endpoint), each `null` when the endpoint does not exist.

#### Scenario: No private network
- **WHEN** `private_network` is null
- **THEN** `instance_private_network` is `null`

### Requirement: Engine helper outputs
`engine_type` SHALL be `"postgresql"` for engines starting with `PostgreSQL-`, `"mysql"` for engines starting with `MySQL-` and `"unknown"` otherwise. `engine_default_port` SHALL be `5432` for PostgreSQL engines and `3306` otherwise.

#### Scenario: PostgreSQL engine
- **WHEN** `engine = "PostgreSQL-16"`
- **THEN** `engine_type` is `"postgresql"` and `engine_default_port` is `5432`

#### Scenario: MySQL engine
- **WHEN** `engine = "MySQL-8"`
- **THEN** `engine_type` is `"mysql"` and `engine_default_port` is `3306`

### Requirement: Setting echo outputs
`encryption_at_rest_enabled` SHALL return `encryption_at_rest` and `backup_enabled` SHALL return the `backup_enabled` input; `instance_id`, `instance_name`, `instance_engine`, `instance_is_ha_cluster`, `instance_node_type`, `instance_region` and `instance_certificate` SHALL return the matching attributes of the instance.

#### Scenario: Defaults echoed
- **WHEN** only the required inputs are set
- **THEN** `encryption_at_rest_enabled` and `backup_enabled` are `true`
