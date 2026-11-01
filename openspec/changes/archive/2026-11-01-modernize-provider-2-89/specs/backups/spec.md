## MODIFIED Requirements

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

### Requirement: Manual backup size warning
A `check` named `manual_backup_volume_size` SHALL warn at plan time when `manual_backups` is not empty and `volume.size_in_gb` is greater than 585, because Scaleway offers manual backups only for storage of at most 585 GB. The plan still succeeds.

#### Scenario: Large volume with a manual backup
- **WHEN** `volume = { type = "sbs_5k", size_in_gb = 600 }` and `manual_backups` has one entry
- **THEN** the plan succeeds with a warning from `check.manual_backup_volume_size`

#### Scenario: Large volume without manual backups
- **WHEN** `volume.size_in_gb = 600` and `manual_backups` is `{}`
- **THEN** no warning is emitted
