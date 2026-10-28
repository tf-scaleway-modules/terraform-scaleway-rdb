## MODIFIED Requirements

### Requirement: Backup region
`backup_same_region` (default `false`) SHALL be passed to the instance when `backup_enabled` is `true`: when `false`, backups are stored in another region. When `backup_enabled` is `false` it is passed as `null`.

#### Scenario: Same-region backups
- **WHEN** `backup_same_region = true`
- **THEN** the instance is planned with `backup_same_region = true`

#### Scenario: Backups disabled
- **WHEN** `backup_enabled = false` and `backup_same_region = true`
- **THEN** the instance receives no `backup_same_region` value

## ADDED Requirements

### Requirement: Manual backup size warning
A `check` named `manual_backup_volume_size` SHALL warn at plan time when `manual_backups` is not empty and `volume_size_in_gb` is greater than 585, because Scaleway offers manual backups only for storage of at most 585 GB. The plan still succeeds.

#### Scenario: Large volume with a manual backup
- **WHEN** `volume_size_in_gb = 600` and `manual_backups` has one entry
- **THEN** the plan succeeds with a warning from `check.manual_backup_volume_size`

#### Scenario: Large volume without manual backups
- **WHEN** `volume_size_in_gb = 600` and `manual_backups` is `{}`
- **THEN** no warning is emitted
