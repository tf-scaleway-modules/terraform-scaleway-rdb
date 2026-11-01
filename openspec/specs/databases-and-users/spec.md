# databases-and-users Specification

## Purpose
Databases, users (with their password forms) and privileges created on the instance.

## Requirements

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
`databases` SHALL map each database key to an object with `id`, `name`, `instance_id`, `managed`, `owner` and `size`. There is no separate `database_ids` output.

#### Scenario: Outputs keyed by map key
- **WHEN** a database is created under the key `app_db`
- **THEN** `databases["app_db"].id` is its ID and `databases["app_db"].name` is its name

### Requirement: Users
The module SHALL create one `scaleway_rdb_user` per entry of `users` (`name`, `is_admin` default `false`, `password_version` default `1`), keyed by the map key, on the instance and in `region`. The password comes from `user_passwords[<key>]` and is sent write-only. Each `name` SHALL start with a letter, contain only letters, digits and underscores, and be 1 to 63 characters long.

#### Scenario: Regular and admin user
- **WHEN** `users` has `app_user` and `admin_user` (`is_admin = true`) and `user_passwords` has both keys
- **THEN** two users are planned, the first with `is_admin = false` and the second with `is_admin = true`

#### Scenario: Invalid user name
- **WHEN** a user has `name = "app-service"`
- **THEN** the plan is rejected with "Usernames must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."

### Requirement: User outputs
`users` SHALL map each user key to an object with `id`, `name` and `is_admin`; it does not expose passwords. There is no separate `user_names` output.

#### Scenario: User outputs
- **WHEN** a user is created under the key `app_user` with `name = "app_service"`
- **THEN** `users["app_user"]` has `id`, `name = "app_service"` and `is_admin`

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

### Requirement: Every user has a password
Each key of `users` MUST have an entry in `user_passwords`.

#### Scenario: Missing password
- **WHEN** `users` has the key `app` and `user_passwords` has no `app` entry
- **THEN** the plan fails with "Every key of users needs a password in user_passwords."

#### Scenario: Password supplied
- **WHEN** `users` and `user_passwords` have the key `app`
- **THEN** the user receives the password through `password_wo` with its `password_version`
