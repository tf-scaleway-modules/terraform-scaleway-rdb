## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Manual backup expiry format
`manual_backups[*].expires_at`, when set, SHALL be a UTC RFC 3339 timestamp written `YYYY-MM-DDTHH:MM:SSZ`, the form the API returns, so the second plan is empty. The provider cannot clear an expiry once set.

#### Scenario: Offset timestamp
- **WHEN** a manual backup has `expires_at = "2027-01-31T01:00:00+01:00"`
- **THEN** the plan is rejected with "expires_at must be a UTC timestamp like 2027-01-31T00:00:00Z."

#### Scenario: Not a date
- **WHEN** a manual backup has `expires_at = "next week"`
- **THEN** the plan is rejected with the same message
