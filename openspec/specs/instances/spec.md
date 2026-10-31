# instances Specification

## Purpose
The Scaleway RDB instance: project resolution, engine, node type, region, storage, encryption, settings, tags, logs policy and admin user.

## Requirements

### Requirement: Single RDB instance
The module SHALL create exactly one `scaleway_rdb_instance` with `name`, `engine`, `node_type`, `region`, `is_ha_cluster`, `encryption_at_rest`, `settings` and `init_settings` taken from the inputs, with create and delete timeouts of 30 minutes and an update timeout of 60 minutes (the provider default, needed by blue/green engine upgrades). `prevent_destroy` is `false`.

#### Scenario: Minimal instance
- **WHEN** `name`, `engine` and `node_type` are set
- **THEN** one RDB instance is planned with those values, encryption at rest enabled and no HA

#### Scenario: Timeouts
- **WHEN** the instance is planned
- **THEN** its timeouts are create `30m`, update `60m` and delete `30m`

### Requirement: Project resolution
The project of the instance SHALL be `project_id` when set; otherwise the ID of the project found by looking up `project_name` in `organization_id` (a `scaleway_account_project` data source, read only when both `organization_id` and `project_name` are set); when none of the three inputs is set, no project is sent and the provider's default project applies. The resolved ID is exposed as the `project_id` output.

#### Scenario: Direct project ID
- **WHEN** `project_id` is set
- **THEN** the instance is created in that project and no data source lookup is made

#### Scenario: Lookup by name
- **WHEN** `organization_id` and `project_name` are set and `project_id` is null
- **THEN** the project is looked up by name in the organization and its ID is used for the instance

#### Scenario: No project input
- **WHEN** `project_id`, `organization_id` and `project_name` are all null
- **THEN** the plan succeeds and the instance receives no `project_id`, so the provider default project applies

### Requirement: Project input combination guard
The instance SHALL be rejected at plan time unless `project_id` is set, or both `organization_id` and `project_name` are set, or all three are null.

#### Scenario: Organization without project name
- **WHEN** `organization_id` is set while `project_id` and `project_name` are null
- **THEN** the plan fails with "Either provide project_id directly, or both organization_id and project_name for lookup, or none to use provider default."

#### Scenario: Project name without organization
- **WHEN** `project_name` is set while `project_id` and `organization_id` are null
- **THEN** the plan fails with the same message

### Requirement: Engine validation
`engine`, when set, SHALL be one of `PostgreSQL-11` to `PostgreSQL-17` or `MySQL-8`. It MAY be null only when `clone_from` is set.

#### Scenario: Unsupported engine
- **WHEN** `engine = "PostgreSQL-10"`
- **THEN** the plan is rejected with "Engine must be PostgreSQL-11 through PostgreSQL-17, or MySQL-8."

#### Scenario: Unsupported MySQL version
- **WHEN** `engine = "MySQL-5"`
- **THEN** the plan is rejected with the same message

### Requirement: Instance name validation
`name` SHALL start with a letter, contain only letters, digits and hyphens, and be 1 to 63 characters long.

#### Scenario: Name starting with a digit
- **WHEN** `name = "1db"`
- **THEN** the plan is rejected with "Instance name must start with a letter, contain only letters, numbers, and hyphens, and be 1-63 characters."

#### Scenario: Name with an underscore
- **WHEN** `name = "my_db"`
- **THEN** the plan is rejected with the same message

### Requirement: Node type validation
`node_type` SHALL start with `db-dev-`, `db-gp-` or `db-play2-`.

#### Scenario: Unknown node family
- **WHEN** `node_type = "gp1-s"`
- **THEN** the plan is rejected with "Node type must start with 'db-dev-', 'db-gp-', or 'db-play2-'."

### Requirement: Region validation
`region`, when set, SHALL be `fr-par`, `nl-ams` or `pl-waw`; when null the provider's default region applies.

#### Scenario: Unsupported region
- **WHEN** `region = "us-east-1"`
- **THEN** the plan is rejected with "Region must be one of: fr-par, nl-ams, pl-waw."

### Requirement: Storage volume
The module SHALL pass `volume_type` and `volume_size_in_gb` to the instance. `volume_type` SHALL be `lssd`, `sbs_5k` or `sbs_15k`; `volume_size_in_gb`, when set, SHALL be between 5 and 10000. For `sbs_5k` and `sbs_15k` the size MUST be set and be a multiple of 5.

#### Scenario: Unsupported volume type
- **WHEN** `volume_type = "bssd"`
- **THEN** the plan is rejected with "Volume type must be one of: lssd, sbs_5k, sbs_15k. Note: bssd is deprecated."

#### Scenario: Volume size out of range
- **WHEN** `volume_size_in_gb = 4`
- **THEN** the plan is rejected with "Volume size must be between 5 and 10000 GB."

#### Scenario: Block storage without a size
- **WHEN** `volume_type = "sbs_5k"` and `volume_size_in_gb` is null
- **THEN** the plan fails with "volume_size_in_gb must be set and be a multiple of 5 when using sbs_5k or sbs_15k volume_type."

#### Scenario: Block storage with a size not multiple of 5
- **WHEN** `volume_type = "sbs_15k"` and `volume_size_in_gb = 52`
- **THEN** the plan fails with the same message

### Requirement: Encryption at rest
`encryption_at_rest` SHALL default to `true` and be passed to the instance.

#### Scenario: Disabled explicitly
- **WHEN** `encryption_at_rest = false`
- **THEN** the instance is planned without encryption at rest

### Requirement: High availability
`is_ha_cluster` SHALL default to `false` and be passed to the instance.

#### Scenario: HA cluster
- **WHEN** `is_ha_cluster = true`
- **THEN** the instance is planned as an HA cluster and `instance_is_ha_cluster` reports it

### Requirement: Admin user
The module SHALL pass `admin_user_name` and the admin password (`admin_user_password` or `admin_user_password_wo`, with `admin_user_password_wo_version`) to the instance. `admin_user_name`, when set, SHALL start with a letter, contain only letters, digits and underscores, and be 1 to 63 characters long. When `admin_user_name` is set, exactly one of `admin_user_password` and `admin_user_password_wo` MUST be set; when it is null, neither may be set.

#### Scenario: Invalid admin name
- **WHEN** `admin_user_name = "admin-user"`
- **THEN** the plan is rejected with "Admin username must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."

#### Scenario: Admin name without password
- **WHEN** `admin_user_name = "admin"` and neither password input is set
- **THEN** the plan fails with "admin_user_name must be set together with exactly one of admin_user_password or admin_user_password_wo, or none of them."

#### Scenario: Both password forms
- **WHEN** `admin_user_name`, `admin_user_password` and `admin_user_password_wo` are all set
- **THEN** the plan fails with the same message

#### Scenario: Password without admin name
- **WHEN** `admin_user_password` is set and `admin_user_name` is null
- **THEN** the plan fails with the same message

### Requirement: Engine settings
`settings` and `init_settings` (both `map(string)`, default `{}`) SHALL be passed unchanged to the instance.

#### Scenario: Custom setting
- **WHEN** `settings = { max_connections = "200" }`
- **THEN** the instance is planned with that setting

### Requirement: Tags
`tags` (`map(string)`, default `{}`) SHALL be converted to a list of `"key=value"` strings and set on the instance.

#### Scenario: Tag conversion
- **WHEN** `tags = { environment = "production" }`
- **THEN** the instance tags are `["environment=production"]`

### Requirement: Logs policy
When `logs_policy` is not null the instance SHALL receive a `logs_policy` block with `max_age_retention` (default 30) and `total_disk_retention` (default 100000000); when null, no block is set. `max_age_retention` SHALL be between 1 and 365 and `total_disk_retention` at least 100000000.

#### Scenario: Logs policy omitted
- **WHEN** `logs_policy` is null
- **THEN** the instance has no `logs_policy` block

#### Scenario: Logs policy with defaults
- **WHEN** `logs_policy = {}`
- **THEN** the instance has a `logs_policy` block with `max_age_retention = 30` and `total_disk_retention = 100000000`

#### Scenario: Retention days out of range
- **WHEN** `logs_policy = { max_age_retention = 0 }`
- **THEN** the plan is rejected with "max_age_retention must be between 1 and 365 days."

#### Scenario: Disk retention too small
- **WHEN** `logs_policy = { total_disk_retention = 1000 }`
- **THEN** the plan is rejected with "total_disk_retention must be at least 100000000 bytes (100MB)."

### Requirement: Clone an existing instance
When `clone_from` (default `null`) is set, the instance SHALL be created as a clone of that Database Instance, keeping its databases, users and permissions; `name` and `node_type` of the inputs apply to the clone. `engine` is not sent and the instance's engine is the source's. `clone_from` SHALL be an instance UUID or `<region>/<UUID>`.

#### Scenario: Clone planned
- **WHEN** `clone_from` is a valid instance ID, `engine` is null, and `node_type` and the source-matching inputs are set
- **THEN** one instance is planned with `clone_from` set and no `engine` argument

#### Scenario: Invalid source identifier
- **WHEN** `clone_from = "not-an-id"`
- **THEN** the plan is rejected with "clone_from must be an instance UUID or <region>/<UUID> (the instance_id format)."

### Requirement: Engine or clone source
Exactly one of `engine` and `clone_from` MUST be set.

#### Scenario: Neither set
- **WHEN** `engine` and `clone_from` are both null
- **THEN** the plan fails with "Set exactly one of engine or clone_from."

#### Scenario: Both set
- **WHEN** `engine = "PostgreSQL-16"` and `clone_from` is a valid instance ID
- **THEN** the plan fails with the same message

### Requirement: Clone keeps the source users
With `clone_from` set, `admin_user_name` and both admin password inputs MUST be null, because the clone inherits the source's users and a different admin name would force a replacement on every plan.

#### Scenario: Admin user with a clone
- **WHEN** `clone_from` is set and `admin_user_name = "admin"` with an admin password
- **THEN** the plan fails with "admin_user_name and the admin password cannot be set with clone_from: the clone keeps the users of its source."

### Requirement: Clone matches the source storage and encryption
With `clone_from` set, `volume_type`, `volume_size_in_gb` (when `volume_type` is not `lssd`), `encryption_at_rest` and `init_settings` MUST equal the values of the source instance, which the module reads once through a data source. The provider does not apply them at clone time, so a difference would show as a permanent diff or a forced replacement.

#### Scenario: Block storage source with the default volume type
- **WHEN** `clone_from` points to an `sbs_5k` instance and `volume_type` is left at `lssd`
- **THEN** the plan fails with "With clone_from, volume_type, volume_size_in_gb (block storage), encryption_at_rest and init_settings must match the source instance."

#### Scenario: Unencrypted source with the secure default
- **WHEN** `clone_from` points to an instance without encryption at rest and `encryption_at_rest` is left at `true`
- **THEN** the plan fails with the same message

#### Scenario: Matching source
- **WHEN** the inputs equal the source's storage, encryption and init settings
- **THEN** the plan succeeds

### Requirement: Clone cannot drop high availability
With `clone_from` set to an HA instance, `is_ha_cluster` MUST be `true`; a non-HA source may be cloned with either value.

#### Scenario: HA source cloned with the default
- **WHEN** `clone_from` points to an HA instance and `is_ha_cluster` is `false`
- **THEN** the plan fails with "clone_from cannot turn off high availability: set is_ha_cluster = true to clone a high-availability source."

#### Scenario: Non-HA source cloned as HA
- **WHEN** `clone_from` points to a non-HA instance and `is_ha_cluster = true`
- **THEN** the plan succeeds
