## MODIFIED Requirements

### Requirement: Supported tool and provider versions
The module SHALL declare `required_version = ">= 1.11.0"` and the provider `scaleway/scaleway` with version constraint `~> 2.89` in `versions.tf`, because `clone_from` exists from provider 2.89.0.

#### Scenario: Older OpenTofu or Terraform
- **WHEN** the module is initialised with OpenTofu or Terraform older than 1.11.0
- **THEN** initialisation fails on the `required_version` constraint

#### Scenario: Provider constraint
- **WHEN** the module is initialised
- **THEN** the `scaleway/scaleway` provider is selected within `~> 2.89`

#### Scenario: Older provider locked by the caller
- **WHEN** the caller's lock file pins `scaleway/scaleway` 2.86.0
- **THEN** `init` fails until the caller runs `init -upgrade`

### Requirement: Required and optional inputs
The module SHALL expose 32 input variables, of which exactly `name` (string) and `node_type` (string) are required; every other input has a default. `engine` and `clone_from` have a `null` default and exactly one of them MUST be set (see the instances capability).

#### Scenario: Only required inputs set
- **WHEN** the caller sets only `name`, `node_type` and `engine`
- **THEN** the inputs are accepted, with no admin user, no database, no user, no privilege, no ACL rule, no read replica and no manual backup

#### Scenario: Missing required input
- **WHEN** the caller omits `name` or `node_type`
- **THEN** the configuration is rejected because the variable has no value

#### Scenario: Existing configuration
- **WHEN** a configuration written for the previous release sets `name`, `engine` and `node_type`
- **THEN** it is accepted unchanged

### Requirement: Input defaults
The optional inputs SHALL default to `null` (scalar and object inputs without a natural empty value), `false`, `true`, a number or an empty map as listed in the scenarios.

#### Scenario: Secure defaults
- **WHEN** the caller sets only the required inputs
- **THEN** encryption at rest is enabled, automated backups are enabled every 24 hours with 14 days of retention, and the instance is not an HA cluster

#### Scenario: Null defaults
- **WHEN** the caller sets only the required inputs
- **THEN** `engine`, `clone_from`, `organization_id`, `project_name`, `project_id`, `region`, `volume_size_in_gb`, `admin_user_name`, `admin_user_password`, `admin_user_password_wo`, `admin_user_password_wo_version`, `private_network` and `logs_policy` are `null`

#### Scenario: Other defaults
- **WHEN** the caller sets only the required inputs
- **THEN** `volume_type` is `"lssd"`, `backup_same_region` and `allow_public_access` are `false`, and `settings`, `init_settings`, `tags`, `databases`, `users`, `privileges`, `acl_rules`, `read_replicas` and `manual_backups` are `{}`

### Requirement: Engine helper outputs
`engine_type` SHALL be `"postgresql"` for engines starting with `PostgreSQL-`, `"mysql"` for engines starting with `MySQL-` and `"unknown"` otherwise. `engine_default_port` SHALL be `5432` for PostgreSQL engines and `3306` otherwise. The engine is the `engine` input, or the engine of the instance when `engine` is null (clone).

#### Scenario: PostgreSQL engine
- **WHEN** `engine = "PostgreSQL-16"`
- **THEN** `engine_type` is `"postgresql"` and `engine_default_port` is `5432`

#### Scenario: MySQL engine
- **WHEN** `engine = "MySQL-8"`
- **THEN** `engine_type` is `"mysql"` and `engine_default_port` is `3306`

#### Scenario: Cloned engine
- **WHEN** `engine` is null and `clone_from` is set
- **THEN** `engine_type` and `engine_default_port` follow the engine the clone reports (known after apply)
