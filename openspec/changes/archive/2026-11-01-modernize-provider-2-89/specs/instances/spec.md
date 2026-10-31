## MODIFIED Requirements

### Requirement: Project resolution
The instance SHALL be created in `project_id` when it is set; when `project_id` is null no project is sent and the provider's default project applies. The module reads no project data source. The project of the instance is exposed as the `project_id` output.

#### Scenario: Direct project ID
- **WHEN** `project_id` is set
- **THEN** the instance is created in that project and no data source lookup is made

#### Scenario: Lookup by name
- **WHEN** the caller sets `project_name` and `organization_id` as in v2
- **THEN** the configuration is rejected because those variables no longer exist

#### Scenario: No project input
- **WHEN** `project_id` is null
- **THEN** the plan succeeds and the instance receives no `project_id`, so the provider default project applies

### Requirement: Storage volume
The module SHALL pass `volume.type` (default `lssd`) and `volume.size_in_gb` (default `null`) of the `volume` object to the instance. `volume.type` SHALL be `lssd`, `sbs_5k` or `sbs_15k`; `volume.size_in_gb`, when set, SHALL be between 5 and 10000. For `sbs_5k` and `sbs_15k` the size MUST be set and be a multiple of 5.

#### Scenario: Unsupported volume type
- **WHEN** `volume = { type = "bssd" }`
- **THEN** the plan is rejected with "Volume type must be one of: lssd, sbs_5k, sbs_15k. Note: bssd is deprecated."

#### Scenario: Volume size out of range
- **WHEN** `volume = { size_in_gb = 4 }`
- **THEN** the plan is rejected with "Volume size must be between 5 and 10000 GB."

#### Scenario: Block storage without a size
- **WHEN** `volume = { type = "sbs_5k" }`
- **THEN** the plan fails with "volume.size_in_gb must be set and be a multiple of 5 when using sbs_5k or sbs_15k volume.type."

#### Scenario: Block storage with a size not multiple of 5
- **WHEN** `volume = { type = "sbs_15k", size_in_gb = 52 }`
- **THEN** the plan fails with the same message

### Requirement: Admin user
The module SHALL create the initial admin user from `admin_user` (`name`, `password_version` default `1`) and the ephemeral `admin_user_password`. `admin_user.name` SHALL start with a letter, contain only letters, digits and underscores, and be 1 to 63 characters long. `admin_user` and `admin_user_password` MUST be set together or both be null.

#### Scenario: Invalid admin name
- **WHEN** `admin_user = { name = "admin-user" }`
- **THEN** the plan is rejected with "Admin username must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."

#### Scenario: Admin name without password
- **WHEN** `admin_user = { name = "admin" }` and `admin_user_password` is null
- **THEN** the plan fails with "admin_user and admin_user_password must be set together, or both be null."

#### Scenario: Both password forms
- **WHEN** the caller sets `admin_user_password_wo` as in v2
- **THEN** the configuration is rejected because that variable no longer exists

#### Scenario: Password without admin name
- **WHEN** `admin_user_password` is set and `admin_user` is null
- **THEN** the plan fails with the same message

### Requirement: Tags
`tags` (`list(string)`, default `[]`) SHALL be applied, de-duplicated, as the tags of the instance, the only taggable resource.

#### Scenario: Tag conversion
- **WHEN** `tags = ["environment=production", "environment=production", "team=platform"]`
- **THEN** the instance tags are `["environment=production", "team=platform"]`

### Requirement: Clone keeps the source users
With `clone_from` set, `admin_user` and `admin_user_password` MUST be null, because the clone inherits the source's users and a different admin name would force a replacement on every plan.

#### Scenario: Admin user with a clone
- **WHEN** `clone_from` is set and `admin_user` with `admin_user_password` is set
- **THEN** the plan fails with "admin_user and admin_user_password cannot be set with clone_from: the clone keeps the users of its source."

### Requirement: Clone matches the source storage and encryption
With `clone_from` set, `volume.type`, `volume.size_in_gb` (when `volume.type` is not `lssd`), `encryption_at_rest` and `init_settings` MUST equal the values of the source instance, which the module reads once through a data source. The provider does not apply them at clone time, so a difference would show as a permanent diff or a forced replacement.

#### Scenario: Block storage source with the default volume type
- **WHEN** `clone_from` points to an `sbs_5k` instance and `volume` is left at its default
- **THEN** the plan fails with "With clone_from, volume.type, volume.size_in_gb (block storage), encryption_at_rest and init_settings must match the source instance."

#### Scenario: Unencrypted source with the secure default
- **WHEN** `clone_from` points to an instance without encryption at rest and `encryption_at_rest` is left at `true`
- **THEN** the plan fails with the same message

#### Scenario: Matching source
- **WHEN** the inputs equal the source's storage, encryption and init settings
- **THEN** the plan succeeds

## REMOVED Requirements

### Requirement: Project input combination guard
**Reason**: `organization_id` and `project_name` no longer exist, so there is no combination to guard.
**Migration**: Set `project_id` or leave it null.
