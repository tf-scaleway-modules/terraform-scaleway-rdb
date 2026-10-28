## ADDED Requirements

### Requirement: Automated backups
The instance SHALL have automated backups enabled when `backup_enabled` is `true` (default) and disabled when it is `false` (`disable_backup = !backup_enabled`). When enabled, `backup_schedule_frequency` (default 24 hours) and `backup_schedule_retention` (default 14 days) SHALL be passed to the instance; when disabled they are passed as `null`.

#### Scenario: Defaults
- **WHEN** only the required inputs are set
- **THEN** automated backups are enabled with a 24-hour frequency and 14 days of retention

#### Scenario: Backups disabled
- **WHEN** `backup_enabled = false`
- **THEN** the instance disables backups and receives no schedule frequency or retention

### Requirement: Backup schedule validation
`backup_schedule_frequency` SHALL be between 1 and 168 hours and `backup_schedule_retention` between 1 and 365 days.

#### Scenario: Frequency too high
- **WHEN** `backup_schedule_frequency = 169`
- **THEN** the plan is rejected with "Backup frequency must be between 1 and 168 hours."

#### Scenario: Frequency too low
- **WHEN** `backup_schedule_frequency = 0`
- **THEN** the plan is rejected with the same message

#### Scenario: Retention out of range
- **WHEN** `backup_schedule_retention = 366`
- **THEN** the plan is rejected with "Backup retention must be between 1 and 365 days."

### Requirement: Backup region
`backup_same_region` (default `false`) SHALL be passed to the instance: when `false`, backups are stored in another region.

#### Scenario: Same-region backups
- **WHEN** `backup_same_region = true`
- **THEN** the instance is planned with `backup_same_region = true`

### Requirement: Manual backups
The module SHALL create one `scaleway_rdb_database_backup` per entry of `manual_backups` (`database_name`, `name`), keyed by the map key, on the instance and in `region`, after the databases of the module. Each `name` SHALL start with a letter, contain only letters, digits, underscores and hyphens, and be 1 to 63 characters long.

#### Scenario: Pre-migration backup
- **WHEN** `manual_backups = { app_backup = { database_name = "application", name = "pre-migration-backup" } }`
- **THEN** one manual backup of `application` named `pre-migration-backup` is planned

#### Scenario: No manual backups
- **WHEN** `manual_backups` is `{}`
- **THEN** no backup resource is planned

#### Scenario: Invalid backup name
- **WHEN** a manual backup has `name = "1-backup"`
- **THEN** the plan is rejected with "Backup names must start with a letter, contain only letters, numbers, underscores, and hyphens, and be 1-63 characters."

### Requirement: Manual backup outputs
`manual_backups` SHALL map each key to an object with `id`, `name`, `database_name`, `instance_id`, `size`, `created_at` and `updated_at`.

#### Scenario: Backup output
- **WHEN** a manual backup is created under the key `app_backup`
- **THEN** `manual_backups["app_backup"].name` is its name
