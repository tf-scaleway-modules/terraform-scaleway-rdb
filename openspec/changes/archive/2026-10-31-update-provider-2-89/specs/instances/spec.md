## MODIFIED Requirements

### Requirement: Single RDB instance
The module SHALL create exactly one `scaleway_rdb_instance` with `name`, `engine`, `node_type`, `region`, `is_ha_cluster`, `encryption_at_rest`, `settings` and `init_settings` taken from the inputs, with create and delete timeouts of 30 minutes and an update timeout of 60 minutes (the provider default, needed by blue/green engine upgrades). `prevent_destroy` is `false`.

#### Scenario: Minimal instance
- **WHEN** `name`, `engine` and `node_type` are set
- **THEN** one RDB instance is planned with those values, encryption at rest enabled and no HA

#### Scenario: Timeouts
- **WHEN** the instance is planned
- **THEN** its timeouts are create `30m`, update `60m` and delete `30m`

### Requirement: Engine validation
`engine`, when set, SHALL be one of `PostgreSQL-11` to `PostgreSQL-17` or `MySQL-8`. It MAY be null only when `clone_from` is set.

#### Scenario: Unsupported engine
- **WHEN** `engine = "PostgreSQL-10"`
- **THEN** the plan is rejected with "Engine must be PostgreSQL-11 through PostgreSQL-17, or MySQL-8."

#### Scenario: Unsupported MySQL version
- **WHEN** `engine = "MySQL-5"`
- **THEN** the plan is rejected with the same message

## ADDED Requirements

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
