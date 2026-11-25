# Scaleway Relational Database Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Scaleway Provider][scaleway-badge]][scaleway-url]

A **production-ready** Terraform/OpenTofu module for managing Scaleway Relational Database (RDB) instances with comprehensive security features, high availability support, and flexible configuration options.

## Features

- **Full RDB Resource Support**: Instance, databases, users, privileges, ACLs, read replicas, and backups
- **Security-First Design**: Encryption at rest enabled by default, restrictive ACL validation, write-only ephemeral passwords that never reach the state or the plan
- **Private or Hybrid Access**: Public, private-only, or private network plus an opt-in public endpoint (`public_endpoint`)
- **High Availability**: Built-in support for HA clusters with automatic failover
- **Flexible Configuration**: Map-based resources for multiple databases, users, and privileges
- **Comprehensive Validation**: Input validation for all critical fields (UUIDs, CIDRs, passwords, naming conventions)
- **Production Defaults**: Sensible defaults for backups, encryption, and retention policies

## Quick Start

### Prerequisites

- OpenTofu >= 1.11.0 and Terraform >= 1.11.0
- Scaleway account with API credentials configured
- Scaleway provider >= 2.89

### Basic Usage

```hcl
module "database" {
  source = "path/to/scaleway-rdb"

  name      = "my-postgres-db"
  engine    = "PostgreSQL-15"
  node_type = "db-dev-s"
  region    = "fr-par"

  # Admin user
  admin_user          = { name = "admin" }
  admin_user_password = var.admin_password # ephemeral variable, never stored in state

  # Create a database
  databases = {
    app = {
      name = "myapp"
    }
  }

  # Create a user; its password comes from user_passwords (same key)
  users = {
    app = {
      name     = "app_user"
      is_admin = false
    }
  }
  user_passwords = {
    app = var.app_password # ephemeral variable
  }

  # Grant privileges
  privileges = {
    app_on_myapp = {
      user_name     = "app_user"
      database_name = "myapp"
      permission    = "readwrite"
    }
  }

  # ACL - Restrict access to specific IPs
  acl_rules = {
    office = {
      ip          = "203.0.113.0/24"
      description = "Office network"
    }
  }

  tags = ["environment=production"]
}
```

`admin_user_password` and `user_passwords` are ephemeral inputs: declare the variables you pass to them
with `sensitive = true` and `ephemeral = true`.

### Production HA Setup

```hcl
module "production_db" {
  source = "path/to/scaleway-rdb"

  name          = "prod-postgres-cluster"
  engine        = "PostgreSQL-16"
  node_type     = "db-gp-s"
  region        = "fr-par"
  is_ha_cluster = true

  # Block storage for scalability
  volume = { type = "sbs_5k", size_in_gb = 100 }

  # Security (defaults, shown for clarity)
  encryption_at_rest = true

  # Backup configuration
  backup = {
    frequency_hours = 12 # Every 12 hours
    retention_days  = 30 # 30 days
    same_region     = false # Geographic redundancy
  }

  # Admin user
  admin_user          = { name = "admin" }
  admin_user_password = var.admin_password

  # Multiple databases
  databases = {
    production = { name = "production" }
    analytics  = { name = "analytics" }
  }

  # Multiple users with different roles
  users = {
    app       = { name = "app_service" }
    readonly  = { name = "readonly_user" }
    analytics = { name = "analytics_service" }
  }
  user_passwords = {
    app       = var.app_password
    readonly  = var.readonly_password
    analytics = var.analytics_password
  }

  # Granular privileges
  privileges = {
    app_production       = { user_name = "app_service", database_name = "production", permission = "readwrite" }
    readonly_production  = { user_name = "readonly_user", database_name = "production", permission = "readonly" }
    analytics_production = { user_name = "analytics_service", database_name = "production", permission = "readonly" }
    analytics_analytics  = { user_name = "analytics_service", database_name = "analytics", permission = "readwrite" }
  }

  # Restrictive ACL
  acl_rules = {
    k8s_cluster = { ip = "10.0.0.0/8", description = "Kubernetes cluster" }
    office      = { ip = "203.0.113.0/24", description = "Office network" }
  }

  # Read replica for scaling reads
  read_replicas = {
    replica_amsterdam = {
      region    = "nl-ams"
      same_zone = false
    }
  }

  tags = ["environment=production", "team=platform"]
}
```

### Private network with a public endpoint

With `private_network`, the instance is private only. Set `public_endpoint = true` to keep a public
endpoint next to it and restrict who may use it with `acl_rules`:

```hcl
  private_network = { pn_id = scaleway_vpc_private_network.this.id, enable_ipam = true }
  public_endpoint = true
  acl_rules       = { office = { ip = "203.0.113.0/24", description = "Office network" } }
```

`connection_host` and `connection_port` return the public endpoint, or the private one when there is none.

### Clone an instance

Set `clone_from` (instance UUID or `<region>/<UUID>`) instead of `engine` to create an
independent copy of an existing instance:

```hcl
module "staging" {
  source = "path/to/scaleway-rdb"

  name          = "staging-db"
  node_type     = "db-gp-s"
  clone_from    = module.database.instance_id
  is_ha_cluster = true # required when the source is a high-availability cluster
}
```

- Inherited: engine, databases, users and permissions of the source. Declare in `databases`,
  `users` and `privileges` only new entries; an existing name fails at apply with an API conflict.
- Must match the source (checked at plan time): `volume.type`, `volume.size_in_gb` (block storage),
  `encryption_at_rest`, `init_settings`. A high-availability source needs `is_ha_cluster = true`.
- Not allowed: `engine`, `admin_user` and `admin_user_password` (the clone takes no password).
- `project_id` is not applied: the clone stays in the project of the source.
- Without `private_network` the clone keeps its public endpoint; with it, the clone is private only
  unless `public_endpoint = true`.
- Setting `clone_from` on an existing instance **replaces** it.

### Engine upgrade

Changing `engine` of an existing instance runs a blue/green upgrade in the provider (update timeout
60 minutes). Writes made between the snapshot and the switch are lost, `scaleway_rdb_acl` may need a
second apply because it uses the instance ID, and the apply must never be re-run while an upgrade is
in progress.

### Upgrading from v2 to v3

v3 removes the legacy input shapes. Run `tofu init -upgrade`; the provider floor (`~> 2.89`) and
`required_version` (`>= 1.11.0`) are unchanged. No resource address changes, so no `moved` block and no
replacement: the first apply updates the instance and each user in place to the write-only password form.

| v2 | v3 |
|----|----|
| `organization_id`, `project_name` | removed: use `project_id` (`null` = default project of the provider) |
| `admin_user_name`, `admin_user_password`, `admin_user_password_wo`, `admin_user_password_wo_version` | `admin_user = { name, password_version }` and the ephemeral `admin_user_password` |
| `users[*].password`, `password_wo`, `password_wo_version` | `users[k] = { name, is_admin, password_version }` and `user_passwords = { k = <ephemeral value> }` |
| `volume_type`, `volume_size_in_gb` | `volume = { type, size_in_gb }` |
| `backup_enabled`, `backup_schedule_frequency`, `backup_schedule_retention`, `backup_same_region` | `backup = { enabled, frequency_hours, retention_days, same_region }` |
| `tags = { environment = "production" }` | `tags = ["environment=production"]` (`[for k, v in old : "${k}=${v}"]`) |
| outputs `admin_password`, `connection_string` | removed (always `null` with write-only passwords): build the URL from `connection_host`, `connection_port` and your secret |
| outputs `instance_endpoint_ip`, `instance_endpoint_port` | `connection_host`, `connection_port` |
| outputs `instance_name`, `instance_node_type`, `instance_is_ha_cluster`, `encryption_at_rest_enabled`, `backup_enabled` | removed: use your own inputs |
| outputs `database_ids`, `user_names`, `acl_rules` | `databases[k].id`, `users[k].name`, your own `acl_rules` input |

New: `public_endpoint` (public endpoint next to a private network), the replica `hostname` in
`read_replicas`, and `connection_host`/`connection_port` falling back to the private endpoint. Rotating a
password now means bumping `admin_user.password_version` or `users[k].password_version`.

### Input reference

Detail of the inputs whose one-line description in the generated table points here.

#### project_id

UUID (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`). `null` uses the default project of the provider configuration. The project of the instance is exposed by the `project_id` output.

#### name

Human-readable identifier, unique within the project. It must start with a letter, contain only letters, numbers and hyphens, and be 1 to 63 characters long.

#### node_type

The node type sets CPU, RAM and performance; availability varies by region. It must start with `db-dev-`, `db-gp-` or `db-play2-`. Common types:

| Family | Types |
|--------|-------|
| Development | `db-dev-s`, `db-dev-m`, `db-dev-l`, `db-dev-xl` |
| General Purpose | `db-gp-xs`, `db-gp-s`, `db-gp-m`, `db-gp-l`, `db-gp-xl` |
| Play2 | `db-play2-pico`, `db-play2-nano`, `db-play2-micro` |

#### engine

`PostgreSQL-11` to `PostgreSQL-17`, or `MySQL-8` (example: `PostgreSQL-15`). Set exactly one of `engine` or `clone_from`; with `clone_from`, leave `engine` `null`: the clone has the engine of its source.

Engine upgrade: see [Engine upgrade](#engine-upgrade) (blue/green upgrade, writes between the snapshot and the switch are lost, `scaleway_rdb_acl` may need a second apply, never re-run the apply while an upgrade is in progress).

#### clone_from

Instance UUID or `<region>/<UUID>` (example: `fr-par/11111111-2222-3333-4444-555555555555`). Requires provider 2.89.0 or later. Setting it on an existing instance **recreates** the instance. The clone keeps the databases, users and permissions of the source: declare in `databases`, `users` and `privileges` only new ones (an existing name fails at apply with an API conflict). The rules of a clone are listed in [Clone an instance](#clone-an-instance):

- Leave `engine` `null`: the clone has the engine of the source.
- Leave `admin_user` and `admin_user_password` `null`: the clone keeps the users of the source.
- `volume.type`, `volume.size_in_gb` (block storage), `encryption_at_rest` and `init_settings` are not applied at clone time and must equal the source values (checked at plan time).
- A high-availability source needs `is_ha_cluster = true`.
- `project_id` is not applied: the clone stays in the project of the source.
- Without `private_network` the clone keeps the public endpoint created by the clone; with it the clone is private unless `public_endpoint` is `true`.

#### region

`fr-par` (Paris, France), `nl-ams` (Amsterdam, Netherlands) or `pl-waw` (Warsaw, Poland). `null` uses the region of the provider configuration.

#### is_ha_cluster

Default `false`. When `true`, a standby node with synchronous replication provides automatic failover (recommended for production). Changing it **recreates** the instance, and an HA cluster costs approximately twice a standalone instance.

#### volume

Example: `{ type = "sbs_5k", size_in_gb = 100 }`. `bssd` is deprecated and no longer supported by Scaleway.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | `string` | `"lssd"` | `lssd` (local SSD, fastest), `sbs_5k` or `sbs_15k` (block storage with 5,000 or 15,000 IOPS) |
| `size_in_gb` | `number` | `null` | 5 to 10000; required for `sbs_5k` and `sbs_15k`, in multiples of 5 |

#### admin_user

Example: `{ name = "admin" }`. Set together with `admin_user_password`, or leave both `null` to skip the initial admin user.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `string` | required | User name, with full administrative privileges on the instance. Must start with a letter, contain only letters, numbers and underscores, and be 1 to 63 characters long |
| `password_version` | `number` | `1` | Version of the write-only password; bump it to apply a new `admin_user_password` |

#### admin_user_password

Sent through the write-only `password_wo` argument: never stored in the state or the plan file (OpenTofu/Terraform >= 1.11). Provide it from an ephemeral source (secrets manager, ephemeral resource) or `TF_VAR_admin_user_password`. Bump `admin_user.password_version` to apply a new value. Requirements (also for `user_passwords`):

- 8 to 128 characters
- At least one uppercase letter, one lowercase letter and one digit
- At least one special character among `!@#$%^&*()_+-=[]{}|;:,.<>?`

#### encryption_at_rest

Default `true` (recommended for production). LUKS encryption of all data, logs and snapshots at the storage volume level; keys are managed by Scaleway. **Irreversible** once enabled; the initial encryption may take about 1 hour per 100 GB of data.

#### backup

Example: `{ frequency_hours = 12, retention_days = 30 }`. `frequency_hours`, `retention_days` and `same_region` apply only when `enabled` is `true`.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | `bool` | `true` | Create automated backups (strongly recommended for production) |
| `frequency_hours` | `number` | `24` | Hours between backups, 1 to 168 |
| `retention_days` | `number` | `14` | Days to keep backups, 1 to 365 |
| `same_region` | `bool` | `false` | `true` stores backups in the region of the instance; `false` stores them in another region for geographic redundancy |

#### settings and init_settings

Both are `map(string)` (default `{}`). `settings` configures the engine behaviour; the available settings depend on the engine:

```hcl
settings = {
  max_connections      = "200"
  effective_cache_size = "1GB" # PostgreSQL
}
```

`init_settings` are applied only when the instance is first created and cannot be changed afterwards without recreating the instance; most settings belong in `settings`.

#### private_network

Connecting to a private network gives isolated network access and is recommended for production. Set exactly one of `ip_net` or `enable_ipam = true`: both together and neither are rejected (the provider fails at apply without one). `null` keeps the instance on its public endpoint.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `pn_id` | `string` | required | ID of the private network to connect to |
| `ip_net` | `string` | `null` | Static IP address in CIDR notation (example: `192.168.1.10/24`) |
| `enable_ipam` | `bool` | `false` | Use Scaleway IPAM for automatic IP assignment |

#### public_endpoint

Default `false`. Only with `private_network`: the instance then answers on both the private network and a public endpoint (reach it through `acl_rules`). Leave `false` for a private-only instance. Without `private_network` the instance is always public and this must stay `false`.

#### tags

Tags of the RDB instance (the other resources do not take tags). Plain strings, by convention `key=value`; duplicates are removed. Example: `["environment=production", "team=platform"]`.

#### databases

Each key is a stable reference used for resource addressing.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `string` | required | Database name: starts with a letter, letters, numbers and underscores only, 1 to 63 characters |

```hcl
databases = {
  app_db       = { name = "application" }
  analytics_db = { name = "analytics" }
}
```

#### users

Each key is a stable reference used for resource addressing. Users are created on the instance and can be granted privileges on databases. The password of each user comes from `user_passwords` under the same key.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `string` | required | User name: starts with a letter, letters, numbers and underscores only, 1 to 63 characters |
| `is_admin` | `bool` | `false` | Grant the admin role |
| `password_version` | `number` | `1` | Version of the write-only password; bump it to apply a new password |

```hcl
users = {
  app_user   = { name = "app_service" }
  admin_user = { name = "dba", is_admin = true, password_version = 2 }
}
```

#### user_passwords

Map of passwords keyed like `users`. Sent through the write-only `password_wo` argument: the values are never stored in the state or the plan file (OpenTofu/Terraform >= 1.11). Provide them from an ephemeral source (secrets manager, ephemeral resource) or `TF_VAR_user_passwords`. Every key of `users` needs an entry, and every key must be a key of `users`. Password requirements: see [admin_user_password](#admin_user_password).

#### privileges

Each privilege grants one user access to one database. Both must exist (created by this module, as the admin user, or outside the module). The names are not cross-checked against `users` and `databases`: a wrong name fails at apply.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `user_name` | `string` | required | Name of the user |
| `database_name` | `string` | required | Name of the database |
| `permission` | `string` | required | `none` (no access), `readonly` (SELECT), `readwrite` (SELECT, INSERT, UPDATE, DELETE) or `all` (full access including administrative operations) |

```hcl
privileges = {
  app_on_appdb          = { user_name = "app_service", database_name = "application", permission = "readwrite" }
  readonly_on_analytics = { user_name = "reporter", database_name = "analytics", permission = "readonly" }
}
```

#### acl_rules

ACL rules define which IP addresses or CIDR ranges can connect to the database. Scaleway allows all IPs (`0.0.0.0/0`) by default; this module requires explicit rules.

**Security**: do not use `0.0.0.0/0` in production unless absolutely necessary; use specific IP ranges or private networks instead. `0.0.0.0/0` is rejected unless `allow_public_access` is `true`; other very wide ranges (prefix shorter than /8, such as `0.0.0.0/1`) only raise a plan-time warning. The Scaleway API does not support IPv6 ACL rules.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `ip` | `string` | required | IPv4 address or CIDR range (example: `203.0.113.0/24`) |
| `description` | `string` | required | Description of the rule |

```hcl
acl_rules = {
  office = { ip = "203.0.113.0/24", description = "Office network" }
  vpn    = { ip = "10.0.0.0/8", description = "VPN network" }
}
```

#### allow_public_access

Default `false`. Safety flag against accidental exposure of the database to the public internet: allows `0.0.0.0/0` in `acl_rules` and silences the warning about other very wide ranges. Set it to `true` only if you understand the security implications; consider private networks or specific IP allowlists instead.

#### read_replicas

Read-only copies for scaling read-heavy workloads, asynchronously replicated from the primary (replication lag may occur). Maximum 3 read replicas per instance.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `region` | `string` | `null` | `fr-par`, `nl-ams` or `pl-waw` |
| `same_zone` | `bool` | `false` | Place the replica in the same zone as the primary |
| `private_network.pn_id` | `string` | required | ID of the private network (when `private_network` is set) |
| `private_network.ip_net` | `string` | `null` | Static IP address in CIDR notation |
| `private_network.enable_ipam` | `bool` | `false` | Use IPAM; `ip_net` or `enable_ipam = true` is required |

```hcl
read_replicas = {
  replica_1 = { region = "nl-ams", same_zone = false }
  replica_2 = { same_zone = true, private_network = { pn_id = "pn-xxxxx", enable_ipam = true } }
}
```

#### manual_backups

Point-in-time exports of specific databases, independent of the automatic backup schedule. Only available for instances with storage <= 585 GB; a plan-time warning is raised when `volume.size_in_gb` is larger. `database_name` is not cross-checked against `databases`.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `database_name` | `string` | required | Name of the database to back up |
| `name` | `string` | required | Backup name: starts with a letter, letters, numbers, underscores and hyphens only, 1 to 63 characters |
| `expires_at` | `string` | `null` | Expiry as a UTC timestamp `YYYY-MM-DDTHH:MM:SSZ`. Without it the backup never expires and is billed until deleted; the provider cannot remove an expiry once set |

```hcl
manual_backups = {
  app_backup = { database_name = "application", name = "pre-migration-backup", expires_at = "2027-01-31T00:00:00Z" }
}
```

#### logs_policy

Controls how long logs are retained and how much disk they may use. `null` keeps the provider default.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_age_retention` | `number` | `30` | Days to retain logs, 1 to 365 |
| `total_disk_retention` | `number` | `100000000` | Maximum log storage in bytes, minimum 100000000 (100 MB) |

## Examples

- [Minimal](./examples/minimal/) - Basic PostgreSQL setup with single database and user
- [Complete](./examples/complete/) - Production HA cluster with multiple databases, users, privileges, and read replicas

## Security Features

### Encryption at Rest

Enabled by default (`encryption_at_rest = true`). Uses LUKS encryption at the storage volume level. Keys are managed by Scaleway.

**Warning**: Encryption cannot be disabled once enabled.

### Automated Backups

Enabled by default with:
- 24-hour backup frequency
- 14-day retention
- Geographic redundancy (backups stored in different region)

### Restrictive ACL

The module validates ACL rules to prevent accidental public exposure:
- `0.0.0.0/0` is blocked by default
- Set `allow_public_access = true` only if absolutely necessary
- Other very wide IPv4 ranges (prefix shorter than /8, such as `0.0.0.0/1`) raise a plan-time warning

### Sensitive Data Protection

- `admin_user_password` and `user_passwords` are `sensitive` and `ephemeral`: sent through the write-only `password_wo` arguments, they land neither in the state nor in the plan file (OpenTofu/Terraform >= 1.11)
- Bump `admin_user.password_version` or `users[*].password_version` to rotate a password
- The certificate output is `sensitive`; no output carries a password
- See [SECURITY.md](SECURITY.md) for what lands in state

## Supported Resources

| Resource | Description |
|----------|-------------|
| `scaleway_rdb_instance` | Primary database instance |
| `scaleway_rdb_database` | Databases within the instance |
| `scaleway_rdb_user` | Database users |
| `scaleway_rdb_privilege` | User privileges on databases |
| `scaleway_rdb_acl` | Network access control |
| `scaleway_rdb_read_replica` | Read replicas for scaling |
| `scaleway_rdb_database_backup` | Manual database backups |

## Supported Engines

- PostgreSQL: 11, 12, 13, 14, 15, 16, 17
- MySQL: 8

## Supported Regions

- `fr-par` - Paris, France
- `nl-ams` - Amsterdam, Netherlands
- `pl-waw` - Warsaw, Poland

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_scaleway"></a> [scaleway](#requirement\_scaleway) | ~> 2.89 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_scaleway"></a> [scaleway](#provider\_scaleway) | ~> 2.89 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [scaleway_rdb_acl.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_acl) | resource |
| [scaleway_rdb_database.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_database) | resource |
| [scaleway_rdb_database_backup.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_database_backup) | resource |
| [scaleway_rdb_instance.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_instance) | resource |
| [scaleway_rdb_privilege.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_privilege) | resource |
| [scaleway_rdb_read_replica.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_read_replica) | resource |
| [scaleway_rdb_user.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_user) | resource |
| [scaleway_rdb_instance.source](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/data-sources/rdb_instance) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acl_rules"></a> [acl\_rules](#input\_acl\_rules) | Map of ACL rules that control which IPv4 addresses or CIDR ranges can connect to the instance, keyed by a stable reference. Each entry sets `ip` and `description`; `0.0.0.0/0` is rejected unless `allow_public_access` is `true`. See Input reference in the README for every attribute and the security notes. | <pre>map(object({<br/>    ip          = string<br/>    description = string<br/>  }))</pre> | `{}` | no |
| <a name="input_admin_user"></a> [admin\_user](#input\_admin\_user) | Initial admin user created with the instance, with full administrative privileges: `name` and an optional `password_version` (default 1) that is bumped to apply a new `admin_user_password`. Set it together with `admin_user_password`, or leave both `null` to skip the initial admin user. See Input reference in the README for the naming rules. | <pre>object({<br/>    name             = string<br/>    password_version = optional(number, 1)<br/>  })</pre> | `null` | no |
| <a name="input_admin_user_password"></a> [admin\_user\_password](#input\_admin\_user\_password) | Password of the initial admin user (`admin_user`), sent through the write-only `password_wo` argument so it never lands in the state or the plan (OpenTofu/Terraform 1.11 or later). Provide it from an ephemeral source or `TF_VAR_admin_user_password`; bump `admin_user.password_version` to apply a new value. See Input reference in the README for the password requirements. | `string` | `null` | no |
| <a name="input_allow_public_access"></a> [allow\_public\_access](#input\_allow\_public\_access) | Safety flag that allows unrestricted public access (`0.0.0.0/0`) in `acl_rules` and silences the warning about other very wide ranges. Enabling it exposes the database to the internet, so prefer private networks or specific IP allowlists. | `bool` | `false` | no |
| <a name="input_backup"></a> [backup](#input\_backup) | Automated backup settings: `enabled` (default `true`), `frequency_hours` (1 to 168, default 24), `retention_days` (1 to 365, default 14) and `same_region` (default `false`, which stores backups in another region). See Input reference in the README for every attribute. | <pre>object({<br/>    enabled         = optional(bool, true)<br/>    frequency_hours = optional(number, 24)<br/>    retention_days  = optional(number, 14)<br/>    same_region     = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_clone_from"></a> [clone\_from](#input\_clone\_from) | Creates the instance as a clone of an existing Database Instance, given as its UUID or `<region>/<UUID>`; `null` creates a new instance. Setting it on an existing instance recreates the instance. See Input reference in the README for the rules that apply to a clone. | `string` | `null` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | Map of databases to create in the RDB instance, keyed by a stable reference used for resource addressing; each entry sets the database `name`. See Input reference in the README for every attribute. | <pre>map(object({<br/>    name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_encryption_at_rest"></a> [encryption\_at\_rest](#input\_encryption\_at\_rest) | Enables LUKS encryption at rest of the data, logs and snapshots, with keys managed by Scaleway; recommended for production. It is irreversible once enabled and the initial encryption takes about 1 hour per 100 GB of data. | `bool` | `true` | no |
| <a name="input_engine"></a> [engine](#input\_engine) | Database engine and version, for example `PostgreSQL-15` or `MySQL-8` (PostgreSQL-11 to PostgreSQL-17, MySQL-8). Set exactly one of `engine` or `clone_from`; `null` is only valid with `clone_from`, the clone then has the engine of its source. See Input reference in the README for the engine upgrade behaviour. | `string` | `null` | no |
| <a name="input_init_settings"></a> [init\_settings](#input\_init\_settings) | Engine settings applied only when the instance is first created; they cannot be changed afterwards without recreating the instance. Most settings belong in `settings` instead. | `map(string)` | `{}` | no |
| <a name="input_is_ha_cluster"></a> [is\_ha\_cluster](#input\_is\_ha\_cluster) | Enables High Availability: a standby node with synchronous replication for automatic failover, recommended for production. Changing it recreates the instance and an HA cluster costs about twice a standalone instance. | `bool` | `false` | no |
| <a name="input_logs_policy"></a> [logs\_policy](#input\_logs\_policy) | Retention of the database logs: `max_age_retention` in days (1 to 365, default 30) and `total_disk_retention` in bytes (at least 100000000, default 100000000). `null` keeps the provider default. See Input reference in the README for every attribute. | <pre>object({<br/>    max_age_retention    = optional(number, 30)<br/>    total_disk_retention = optional(number, 100000000)<br/>  })</pre> | `null` | no |
| <a name="input_manual_backups"></a> [manual\_backups](#input\_manual\_backups) | Map of manual database backups to create, keyed by a stable reference. Each entry sets `database_name`, `name` and an optional `expires_at` UTC timestamp. See Input reference in the README for every attribute. | <pre>map(object({<br/>    database_name = string<br/>    name          = string<br/>    expires_at    = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the RDB instance, unique within the project. Must start with a letter, contain only letters, numbers and hyphens, and be 1 to 63 characters long. | `string` | n/a | yes |
| <a name="input_node_type"></a> [node\_type](#input\_node\_type) | Node type of the database instance, which sets its CPU, RAM and performance (for example `db-dev-s`, `db-gp-xs` or `db-play2-pico`). Must start with `db-dev-`, `db-gp-` or `db-play2-`; availability varies by region. See Input reference in the README for the common types. | `string` | n/a | yes |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | Private network of the RDB instance: `pn_id` is the private network ID and exactly one of `ip_net` (static IP in CIDR notation) or `enable_ipam = true` must be set. `null` keeps the instance on its public endpoint. See Input reference in the README for every attribute. | <pre>object({<br/>    pn_id       = string<br/>    ip_net      = optional(string)<br/>    enable_ipam = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_privileges"></a> [privileges](#input\_privileges) | Map of privileges granted to users on databases, keyed by a stable reference. Each entry sets `user_name`, `database_name` and `permission` (`none`, `readonly`, `readwrite` or `all`). See Input reference in the README for every attribute. | <pre>map(object({<br/>    user_name     = string<br/>    database_name = string<br/>    permission    = string<br/>  }))</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Scaleway Project ID (UUID) in which the RDB instance is created. `null` uses the default project of the provider configuration; the project actually used is exposed by the `project_id` output. | `string` | `null` | no |
| <a name="input_public_endpoint"></a> [public\_endpoint](#input\_public\_endpoint) | Keeps a public endpoint next to the private network, reachable through `acl_rules`. Only valid with `private_network`; without it the instance is always public and this must stay `false`, which gives a private-only instance. | `bool` | `false` | no |
| <a name="input_read_replicas"></a> [read\_replicas](#input\_read\_replicas) | Map of read replicas (at most 3), keyed by a stable reference. Each entry sets an optional `region`, `same_zone` and an optional `private_network`. See Input reference in the README for every attribute. | <pre>map(object({<br/>    region    = optional(string)<br/>    same_zone = optional(bool, false)<br/>    private_network = optional(object({<br/>      pn_id       = string<br/>      ip_net      = optional(string)<br/>      enable_ipam = optional(bool, false)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_region"></a> [region](#input\_region) | Scaleway region in which the RDB instance is deployed: `fr-par`, `nl-ams` or `pl-waw`. `null` uses the region of the provider configuration. | `string` | `null` | no |
| <a name="input_settings"></a> [settings](#input\_settings) | Database engine settings as a map of strings, for example `max_connections` set to `200`. The available settings depend on the engine. | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the RDB instance, the only resource of the module that takes tags. Tags are plain strings, by convention `key=value`, and duplicates are removed. | `list(string)` | `[]` | no |
| <a name="input_user_passwords"></a> [user\_passwords](#input\_user\_passwords) | Passwords of the database users, keyed like `users`, sent through the write-only `password_wo` argument so they never land in the state or the plan (OpenTofu/Terraform 1.11 or later). Every key of `users` needs an entry and every key must be a key of `users`; provide them from an ephemeral source or `TF_VAR_user_passwords`. See Input reference in the README for the password requirements. | `map(string)` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | Map of database users to create, keyed by a stable reference that is also the key of the user password in `user_passwords`. Each entry sets `name`, `is_admin` and `password_version`. See Input reference in the README for every attribute. | <pre>map(object({<br/>    name             = string<br/>    is_admin         = optional(bool, false)<br/>    password_version = optional(number, 1)<br/>  }))</pre> | `{}` | no |
| <a name="input_volume"></a> [volume](#input\_volume) | Storage volume of the database: `type` is `lssd` (local SSD, default), `sbs_5k` or `sbs_15k` (block storage with 5,000 or 15,000 IOPS) and `size_in_gb` is 5 to 10000. See Input reference in the README for every attribute. | <pre>object({<br/>    type       = optional(string, "lssd")<br/>    size_in_gb = optional(number)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acl_id"></a> [acl\_id](#output\_acl\_id) | The ID of the ACL resource, null when there are no acl\_rules. |
| <a name="output_connection_host"></a> [connection\_host](#output\_connection\_host) | The IP address for database connections: the public endpoint, or the private network endpoint when there is none. |
| <a name="output_connection_port"></a> [connection\_port](#output\_connection\_port) | The port for database connections: the public endpoint, or the private network endpoint when there is none. |
| <a name="output_databases"></a> [databases](#output\_databases) | Map of database keys to their details. |
| <a name="output_engine_default_port"></a> [engine\_default\_port](#output\_engine\_default\_port) | The default port for the database engine (5432 for PostgreSQL, 3306 for MySQL). |
| <a name="output_engine_type"></a> [engine\_type](#output\_engine\_type) | The detected engine type (postgresql or mysql). |
| <a name="output_instance_certificate"></a> [instance\_certificate](#output\_instance\_certificate) | The PEM-encoded TLS certificate for secure connections. |
| <a name="output_instance_engine"></a> [instance\_engine](#output\_instance\_engine) | The database engine and version. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | The ID of the RDB instance. |
| <a name="output_instance_load_balancer"></a> [instance\_load\_balancer](#output\_instance\_load\_balancer) | Public (load balancer) endpoint of the RDB instance, null when it has none. |
| <a name="output_instance_private_network"></a> [instance\_private\_network](#output\_instance\_private\_network) | Private network endpoint of the RDB instance, null when it has none. |
| <a name="output_instance_region"></a> [instance\_region](#output\_instance\_region) | The region where the RDB instance is deployed. |
| <a name="output_manual_backups"></a> [manual\_backups](#output\_manual\_backups) | Map of manual backup keys to their details. |
| <a name="output_privileges"></a> [privileges](#output\_privileges) | Map of privilege keys to their details. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The ID of the Scaleway project of the instance (the provider default project when the project\_id input is null). |
| <a name="output_read_replicas"></a> [read\_replicas](#output\_read\_replicas) | Map of read replica keys to their endpoint information (ip, port and hostname). |
| <a name="output_users"></a> [users](#output\_users) | Map of user keys to their details (passwords not exposed). |
<!-- END_TF_DOCS -->

## Contributing

### Prerequisites

This module uses [mise](https://mise.jdx.dev/) for tool management:

```bash
# Install mise (if not already installed)
curl https://mise.run | sh

# Install required tools
mise install

# Install pre-commit hooks
pre-commit install --install-hooks

# Register the OpenSpec standards stores (once per machine)
mise run spec-setup
```

Changes are planned with [OpenSpec](https://github.com/Fission-AI/OpenSpec): `openspec/specs/` is the module's current contract and [AGENTS.md](AGENTS.md) routes to the engineering standards. Behaviour changes, new inputs, outputs or resources go through a change proposal (`/openspec-propose`) before any code.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes (behaviour changes start with a change proposal, see above)
4. Run validation:
   ```bash
   tofu fmt -recursive
   tofu validate
   mise run spec-validate
   ```
5. Pre-commit hooks will automatically run on commit
6. Submit a merge request

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

## Disclaimer

This module is provided "as is" without warranty. Always test in non-production environments first.

---

[apache]: https://opensource.org/licenses/Apache-2.0
[apache-shield]: https://img.shields.io/badge/License-Apache%202.0-blue.svg
[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.11-623CE4
[terraform-url]: https://www.terraform.io
[scaleway-badge]: https://img.shields.io/badge/Scaleway%20Provider-%3E%3D2.89-4f0599
[scaleway-url]: https://registry.terraform.io/providers/scaleway/scaleway/
