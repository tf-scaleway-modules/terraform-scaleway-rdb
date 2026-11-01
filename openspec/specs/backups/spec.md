# backups Specification

## Purpose
Automated backup schedule and manual database backups.

## Requirements

### Requirement: Automated backups
The instance SHALL have automated backups enabled when `backup.enabled` is `true` (default) and disabled when it is `false` (`disable_backup = !backup.enabled`). When enabled, `backup.frequency_hours` (default 24) and `backup.retention_days` (default 14) SHALL be passed to the instance; when disabled they are passed as `null`.

#### Scenario: Defaults
- **WHEN** `backup` is left at its default
- **THEN** automated backups are enabled with a 24-hour frequency and 14 days of retention

#### Scenario: Backups disabled
- **WHEN** `backup = { enabled = false }`
- **THEN** the instance disables backups and receives no schedule frequency or retention

### Requirement: Backup schedule validation
`backup.frequency_hours` SHALL be between 1 and 168 and `backup.retention_days` between 1 and 365.

#### Scenario: Frequency too high
- **WHEN** `backup = { frequency_hours = 169 }`
- **THEN** the plan is rejected with "Backup frequency must be between 1 and 168 hours."

#### Scenario: Frequency too low
- **WHEN** `backup = { frequency_hours = 0 }`
- **THEN** the plan is rejected with the same message

#### Scenario: Retention out of range
- **WHEN** `backup = { retention_days = 366 }`
- **THEN** the plan is rejected with "Backup retention must be between 1 and 365 days."

### Requirement: Backup region
`backup.same_region` (default `false`) SHALL be passed to the instance when `backup.enabled` is `true`: when `false`, backups are stored in another region. When `backup.enabled` is `false` it is passed as `null`.

#### Scenario: Same-region backups
- **WHEN** `backup = { same_region = true }`
- **THEN** the instance is planned with `backup_same_region = true`

#### Scenario: Backups disabled
- **WHEN** `backup = { enabled = false, same_region = true }`
- **THEN** the instance receives no `backup_same_region` value

### Requirement: Manual backups
The module SHALL create one `scaleway_rdb_database_backup` per entry of `manual_backups` (`database_name`, `name`, optional `expires_at`), keyed by the map key, on the instance and in `region`, after the databases of the module. Each `name` SHALL start with a letter, contain only letters, digits, underscores and hyphens, and be 1 to 63 characters long. `expires_at`, when set, is the expiry of the backup; when null the backup does not expire.

#### Scenario: Pre-migration backup
- **WHEN** `manual_backups = { app_backup = { database_name = "application", name = "pre-migration-backup" } }`
- **THEN** one manual backup of `application` named `pre-migration-backup` is planned, without expiry

#### Scenario: No manual backups
- **WHEN** `manual_backups` is `{}`
- **THEN** no backup resource is planned

#### Scenario: Invalid backup name
- **WHEN** a manual backup has `name = "1-backup"`
- **THEN** the plan is rejected with "Backup names must start with a letter, contain only letters, numbers, underscores, and hyphens, and be 1-63 characters."

#### Scenario: Backup with an expiry
- **WHEN** a manual backup has `expires_at = "2027-01-31T00:00:00Z"`
- **THEN** the backup is planned with that expiry

### Requirement: Manual backup outputs
`manual_backups` SHALL map each key to an object with `id`, `name`, `database_name`, `instance_id`, `size`, `expires_at`, `created_at` and `updated_at`.

#### Scenario: Backup output
- **WHEN** a manual backup is created under the key `app_backup`
- **THEN** `manual_backups["app_backup"].name` is its name

### Requirement: Manual backup size warning
A `check` named `manual_backup_volume_size` SHALL warn at plan time when `manual_backups` is not empty and `volume.size_in_gb` is greater than 585, because Scaleway offers manual backups only for storage of at most 585 GB. The plan still succeeds.

#### Scenario: Large volume with a manual backup
- **WHEN** `volume = { type = "sbs_5k", size_in_gb = 600 }` and `manual_backups` has one entry
- **THEN** the plan succeeds with a warning from `check.manual_backup_volume_size`

#### Scenario: Large volume without manual backups
- **WHEN** `volume.size_in_gb = 600` and `manual_backups` is `{}`
- **THEN** no warning is emitted

### Requirement: Manual backup expiry format
`manual_backups[*].expires_at`, when set, SHALL be a UTC RFC 3339 timestamp written `YYYY-MM-DDTHH:MM:SSZ`, the form the API returns, so the second plan is empty. The provider cannot clear an expiry once set.

#### Scenario: Offset timestamp
- **WHEN** a manual backup has `expires_at = "2027-01-31T01:00:00+01:00"`
- **THEN** the plan is rejected with "expires_at must be a UTC timestamp like 2027-01-31T00:00:00Z."

#### Scenario: Not a date
- **WHEN** a manual backup has `expires_at = "next week"`
- **THEN** the plan is rejected with the same message
