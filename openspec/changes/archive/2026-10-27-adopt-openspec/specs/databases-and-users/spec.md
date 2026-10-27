## ADDED Requirements

### Requirement: Databases
The module SHALL create one `scaleway_rdb_database` per entry of `databases` (`map(object({ name = string }))`, default `{}`), keyed by the map key, on the instance and in `region`. Each `name` SHALL start with a letter, contain only letters, digits and underscores, and be 1 to 63 characters long.

#### Scenario: Two databases
- **WHEN** `databases = { app_db = { name = "application" }, analytics_db = { name = "analytics" } }`
- **THEN** two databases named `application` and `analytics` are planned, addressed by `app_db` and `analytics_db`

#### Scenario: No databases
- **WHEN** `databases` is `{}`
- **THEN** no database resource is planned

#### Scenario: Invalid database name
- **WHEN** `databases = { bad = { name = "my-db" } }`
- **THEN** the plan is rejected with "Database names must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."

### Requirement: Database outputs
`database_ids` SHALL map each database key to its ID, and `databases` SHALL map each key to an object with `id`, `name`, `instance_id`, `managed`, `owner` and `size`.

#### Scenario: Outputs keyed by map key
- **WHEN** a database is created under the key `app_db`
- **THEN** `database_ids["app_db"]` is its ID and `databases["app_db"].name` is its name

### Requirement: Users
The module SHALL create one `scaleway_rdb_user` per entry of `users`, keyed by the map key, on the instance and in `region`, with `name`, `is_admin` (default `false`) and the password passed as `password` or write-only `password_wo` with `password_wo_version`. Each `name` SHALL start with a letter, contain only letters, digits and underscores, and be 1 to 63 characters long.

#### Scenario: Regular and admin user
- **WHEN** `users` has `app_user` (`is_admin` unset) and `admin_user` (`is_admin = true`), each with a valid password
- **THEN** two users are planned, the first with `is_admin = false` and the second with `is_admin = true`

#### Scenario: Invalid user name
- **WHEN** a user has `name = "app-service"`
- **THEN** the plan is rejected with "Usernames must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."

### Requirement: Exactly one password form per user
Each entry of `users` SHALL set exactly one of `password` and `password_wo`.

#### Scenario: No password
- **WHEN** a user sets neither `password` nor `password_wo`
- **THEN** the plan is rejected with "Each user must set exactly one of password or password_wo."

#### Scenario: Both passwords
- **WHEN** a user sets both `password` and `password_wo`
- **THEN** the plan is rejected with the same message

#### Scenario: Write-only password
- **WHEN** a user sets `password_wo` and `password_wo_version = 2`
- **THEN** the user receives the password through the provider's `password_wo` argument with version 2

### Requirement: User outputs
`user_names` SHALL map each user key to the user name, and `users` SHALL map each key to an object with `id`, `name` and `is_admin`; neither exposes passwords.

#### Scenario: User outputs
- **WHEN** a user is created under the key `app_user` with `name = "app_service"`
- **THEN** `user_names["app_user"]` is `"app_service"` and `users["app_user"]` has `id`, `name` and `is_admin`

### Requirement: Privileges
The module SHALL create one `scaleway_rdb_privilege` per entry of `privileges` (`user_name`, `database_name`, `permission`), keyed by the map key, on the instance and in `region`, after the databases and users of the module. `permission` SHALL be `none`, `readonly`, `readwrite` or `all`.

#### Scenario: Grant read-only access
- **WHEN** `privileges = { r = { user_name = "reporter", database_name = "analytics", permission = "readonly" } }`
- **THEN** one privilege is planned for that user and database with permission `readonly`

#### Scenario: Unknown permission
- **WHEN** a privilege has `permission = "admin"`
- **THEN** the plan is rejected with "Permission must be one of: none, readonly, readwrite, all."

### Requirement: Privilege outputs
`privileges` SHALL map each privilege key to an object with `id`, `user_name`, `database_name` and `permission`.

#### Scenario: Privilege output
- **WHEN** a privilege is created under the key `r`
- **THEN** `privileges["r"].permission` is its permission
