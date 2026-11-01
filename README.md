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

- Terraform >= 1.11 or OpenTofu >= 1.11
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
`required_version` (`>= 1.11`) are unchanged. No resource address changes, so no `moved` block and no
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
| <a name="input_acl_rules"></a> [acl\_rules](#input\_acl\_rules) | Map of ACL rules to control network access to the RDB instance.<br/><br/>ACL rules define which IP addresses or CIDR ranges can connect<br/>to the database. By default, Scaleway allows all IPs (0.0.0.0/0).<br/>This module requires explicit ACL rules for security.<br/><br/>SECURITY: Do not use 0.0.0.0/0 in production unless absolutely<br/>necessary. Use specific IP ranges or private networks instead.<br/>0.0.0.0/0 is rejected unless allow\_public\_access is true; other very<br/>wide ranges (prefix shorter than /8, such as 0.0.0.0/1) only raise a<br/>plan-time warning. The Scaleway API does not support IPv6 ACL rules.<br/><br/>Example:<br/>{<br/>  office = {<br/>    ip          = "203.0.113.0/24"<br/>    description = "Office network"<br/>  }<br/>  vpn = {<br/>    ip          = "10.0.0.0/8"<br/>    description = "VPN network"<br/>  }<br/>} | <pre>map(object({<br/>    ip          = string<br/>    description = string<br/>  }))</pre> | `{}` | no |
| <a name="input_admin_user"></a> [admin\_user](#input\_admin\_user) | Initial admin user created with the instance.<br/><br/>- name: user name, with full administrative privileges on the instance<br/>- password\_version: version of the write-only password; bump it to apply a<br/>  new admin\_user\_password (default 1)<br/><br/>Set together with admin\_user\_password, or leave both null to skip the<br/>initial admin user.<br/><br/>Naming rules:<br/>- Must start with a letter<br/>- Can contain letters, numbers, and underscores<br/>- Must be 1-63 characters long<br/><br/>Example: { name = "admin" } | <pre>object({<br/>    name             = string<br/>    password_version = optional(number, 1)<br/>  })</pre> | `null` | no |
| <a name="input_admin_user_password"></a> [admin\_user\_password](#input\_admin\_user\_password) | Password of the initial admin user (admin\_user).<br/><br/>Sent through the write-only password\_wo argument: never stored in the<br/>state or the plan file (OpenTofu/Terraform >= 1.11). Provide it from an<br/>ephemeral source (secrets manager, ephemeral resource) or<br/>TF\_VAR\_admin\_user\_password. Bump admin\_user.password\_version to apply a<br/>new value.<br/><br/>Password requirements:<br/>- 8 to 128 characters<br/>- At least one uppercase letter<br/>- At least one lowercase letter<br/>- At least one digit<br/>- At least one special character (!@#$%^&*()\_+-=[]{}\|;:,.<>?) | `string` | `null` | no |
| <a name="input_allow_public_access"></a> [allow\_public\_access](#input\_allow\_public\_access) | Allow unrestricted public access (0.0.0.0/0) in ACL rules and silence<br/>the warning about other very wide ranges.<br/><br/>This is a safety flag to prevent accidental exposure of the database<br/>to the public internet. Set to true only if you understand the<br/>security implications.<br/><br/>WARNING: Enabling public access exposes your database to the internet.<br/>Consider using private networks or specific IP allowlists instead.<br/><br/>Default: false | `bool` | `false` | no |
| <a name="input_backup"></a> [backup](#input\_backup) | Automated backup settings.<br/><br/>- enabled: create automated backups (default true, strongly recommended for production)<br/>- frequency\_hours: hours between backups, 1 to 168 (default 24)<br/>- retention\_days: days to keep backups, 1 to 365 (default 14)<br/>- same\_region: store backups in the region of the instance; false (default)<br/>  stores them in another region for geographic redundancy<br/><br/>frequency\_hours, retention\_days and same\_region apply only when enabled is true.<br/><br/>Example: { frequency\_hours = 12, retention\_days = 30 } | <pre>object({<br/>    enabled         = optional(bool, true)<br/>    frequency_hours = optional(number, 24)<br/>    retention_days  = optional(number, 14)<br/>    same_region     = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_clone_from"></a> [clone\_from](#input\_clone\_from) | Create the instance as a clone of an existing Database Instance.<br/><br/>Accepts the instance UUID or <region>/<UUID>. The clone keeps the databases, users and<br/>permissions of the source; declare in databases, users and privileges only new ones<br/>(an existing name fails at apply with an API conflict). Provider 2.89.0 or later.<br/><br/>Rules:<br/>- Leave engine null: the clone has the engine of the source.<br/>- Leave admin\_user and admin\_user\_password null: the clone keeps the users of the source.<br/>- volume.type, volume.size\_in\_gb (block storage), encryption\_at\_rest and init\_settings are not<br/>  applied at clone time and must equal the source values (checked at plan time).<br/>- A high-availability source needs is\_ha\_cluster = true.<br/>- project\_id is not applied: the clone stays in the project of the source.<br/>- Without private\_network the clone keeps the public endpoint created by the clone;<br/>  with it the clone is private unless public\_endpoint is true.<br/><br/>WARNING: Setting this value on an existing instance will recreate the instance.<br/><br/>Example: "fr-par/11111111-2222-3333-4444-555555555555" | `string` | `null` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | Map of databases to create within the RDB instance.<br/><br/>Each database is identified by a unique key used for Terraform resource<br/>addressing. The 'name' field is the actual database name.<br/><br/>Example:<br/>{<br/>  app\_db = {<br/>    name = "application"<br/>  }<br/>  analytics\_db = {<br/>    name = "analytics"<br/>  }<br/>} | <pre>map(object({<br/>    name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_encryption_at_rest"></a> [encryption\_at\_rest](#input\_encryption\_at\_rest) | Enable encryption at rest using LUKS.<br/><br/>When enabled, all data, logs, and snapshots are encrypted at the<br/>storage volume level. Keys are managed by Scaleway.<br/><br/>WARNING: This setting is IRREVERSIBLE once enabled.<br/>WARNING: Initial encryption may take ~1 hour per 100GB of data.<br/><br/>Default: true (recommended for production) | `bool` | `true` | no |
| <a name="input_engine"></a> [engine](#input\_engine) | Database engine and version.<br/><br/>Set exactly one of engine or clone\_from. With clone\_from, leave engine null:<br/>the clone has the engine of its source.<br/><br/>Supported engines:<br/>- PostgreSQL: PostgreSQL-11, PostgreSQL-12, PostgreSQL-13, PostgreSQL-14, PostgreSQL-15, PostgreSQL-16, PostgreSQL-17<br/>- MySQL: MySQL-8<br/><br/>Example: "PostgreSQL-15"<br/><br/>Engine upgrade: changing the version of an existing instance runs a blue/green<br/>upgrade in the provider. Writes made between the snapshot and the switch are<br/>lost, scaleway\_rdb\_acl may need a second apply because it uses the instance ID,<br/>and the apply must never be re-run while an upgrade is in progress. | `string` | `null` | no |
| <a name="input_init_settings"></a> [init\_settings](#input\_init\_settings) | Initial database engine settings applied at creation.<br/><br/>These settings are applied only when the instance is first created<br/>and cannot be changed afterward without recreating the instance.<br/><br/>Use with caution - most settings should go in 'settings' instead. | `map(string)` | `{}` | no |
| <a name="input_is_ha_cluster"></a> [is\_ha\_cluster](#input\_is\_ha\_cluster) | Enable High Availability (HA) mode.<br/><br/>When enabled, creates a standby node with synchronous replication<br/>for automatic failover. Recommended for production workloads.<br/><br/>WARNING: Changing this value will recreate the instance.<br/>WARNING: HA clusters cost approximately 2x a standalone instance.<br/><br/>Default: false | `bool` | `false` | no |
| <a name="input_logs_policy"></a> [logs\_policy](#input\_logs\_policy) | Configuration for database logs retention.<br/><br/>Controls how long logs are retained and how much disk they may use.<br/><br/>Configuration:<br/>- max\_age\_retention: Days to retain logs (1-365)<br/>- total\_disk\_retention: Maximum log storage in bytes (minimum 100000000 = 100MB) | <pre>object({<br/>    max_age_retention    = optional(number, 30)<br/>    total_disk_retention = optional(number, 100000000)<br/>  })</pre> | `null` | no |
| <a name="input_manual_backups"></a> [manual\_backups](#input\_manual\_backups) | Map of manual database backups to create.<br/><br/>Manual backups are point-in-time exports of specific databases.<br/>They are independent of the automatic backup schedule.<br/><br/>expires\_at (optional) is the expiry of the backup, a UTC timestamp written<br/>YYYY-MM-DDTHH:MM:SSZ. Without it the backup never expires and is billed until<br/>deleted. The provider cannot remove an expiry once set.<br/><br/>Note: Manual backups are only available for instances with<br/>storage <= 585GB; a plan-time warning is raised when volume.size\_in\_gb<br/>is larger. database\_name is not cross-checked against databases.<br/><br/>Example:<br/>{<br/>  app\_backup = {<br/>    database\_name = "application"<br/>    name          = "pre-migration-backup"<br/>    expires\_at    = "2027-01-31T00:00:00Z"<br/>  }<br/>} | <pre>map(object({<br/>    database_name = string<br/>    name          = string<br/>    expires_at    = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the RDB instance.<br/><br/>This is a human-readable identifier for the database instance.<br/>Must be unique within the project.<br/><br/>Naming rules:<br/>- Must start with a letter<br/>- Can contain letters, numbers, and hyphens<br/>- Must be 1-63 characters long | `string` | n/a | yes |
| <a name="input_node_type"></a> [node\_type](#input\_node\_type) | The type of database instance node.<br/><br/>Node type determines CPU, RAM, and performance characteristics.<br/>Available types vary by region.<br/><br/>Common types:<br/>- Development: db-dev-s, db-dev-m, db-dev-l, db-dev-xl<br/>- General Purpose: db-gp-xs, db-gp-s, db-gp-m, db-gp-l, db-gp-xl<br/>- Play2: db-play2-pico, db-play2-nano, db-play2-micro<br/><br/>Example: "db-dev-s" | `string` | n/a | yes |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | Private network configuration for the RDB instance.<br/><br/>Connecting to a private network provides isolated network access<br/>and is recommended for production environments.<br/><br/>Configuration:<br/>- pn\_id: The ID of the private network to connect to<br/>- ip\_net: Static IP address with CIDR notation (e.g., "192.168.1.10/24")<br/>- enable\_ipam: Use Scaleway IPAM for automatic IP assignment<br/><br/>Set exactly one of ip\_net or enable\_ipam = true: both together and<br/>neither are rejected (the provider fails at apply without one). | <pre>object({<br/>    pn_id       = string<br/>    ip_net      = optional(string)<br/>    enable_ipam = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_privileges"></a> [privileges](#input\_privileges) | Map of user privileges to grant on databases.<br/><br/>Each privilege grants a specific user access to a specific database.<br/>Both the user and database must exist (created via this module, as the<br/>admin user, or outside the module). The names are not cross-checked<br/>against users and databases: a wrong name fails at apply.<br/><br/>Permission levels:<br/>- none: No access<br/>- readonly: SELECT queries only<br/>- readwrite: SELECT, INSERT, UPDATE, DELETE<br/>- all: Full access including administrative operations<br/><br/>Example:<br/>{<br/>  app\_on\_appdb = {<br/>    user\_name     = "app\_service"<br/>    database\_name = "application"<br/>    permission    = "readwrite"<br/>  }<br/>  readonly\_on\_analytics = {<br/>    user\_name     = "reporter"<br/>    database\_name = "analytics"<br/>    permission    = "readonly"<br/>  }<br/>} | <pre>map(object({<br/>    user_name     = string<br/>    database_name = string<br/>    permission    = string<br/>  }))</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Scaleway Project ID where the RDB instance will be created.<br/><br/>Leave null to use the default project of the provider configuration.<br/>The project of the instance is exposed by the project\_id output.<br/><br/>Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) | `string` | `null` | no |
| <a name="input_public_endpoint"></a> [public\_endpoint](#input\_public\_endpoint) | Keep a public endpoint next to the private network.<br/><br/>Only with private\_network: the instance then answers on both the private<br/>network and a public endpoint (reach it through acl\_rules). Leave false<br/>for a private-only instance. Without private\_network the instance is<br/>always public and this must stay false.<br/><br/>Default: false | `bool` | `false` | no |
| <a name="input_read_replicas"></a> [read\_replicas](#input\_read\_replicas) | Map of read replicas to create for read scaling.<br/><br/>Read replicas provide read-only copies of the database for<br/>scaling read-heavy workloads. Data is asynchronously replicated<br/>from the primary instance.<br/><br/>Limits:<br/>- Maximum 3 read replicas per instance<br/>- Read replicas are read-only (cannot write)<br/>- Replication lag may occur<br/><br/>Example:<br/>{<br/>  replica\_1 = {<br/>    region    = "nl-ams"<br/>    same\_zone = false<br/>  }<br/>  replica\_2 = {<br/>    same\_zone = true<br/>    private\_network = {<br/>      pn\_id       = "pn-xxxxx"<br/>      enable\_ipam = true<br/>    }<br/>  }<br/>} | <pre>map(object({<br/>    region    = optional(string)<br/>    same_zone = optional(bool, false)<br/>    private_network = optional(object({<br/>      pn_id       = string<br/>      ip_net      = optional(string)<br/>      enable_ipam = optional(bool, false)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_region"></a> [region](#input\_region) | Scaleway region where the RDB instance will be deployed.<br/><br/>Available regions:<br/>- fr-par: Paris, France<br/>- nl-ams: Amsterdam, Netherlands<br/>- pl-waw: Warsaw, Poland<br/><br/>If not specified, uses the provider's default region. | `string` | `null` | no |
| <a name="input_settings"></a> [settings](#input\_settings) | Database engine configuration settings.<br/><br/>These settings configure the database engine behavior.<br/>Available settings depend on the engine type.<br/><br/>Example for PostgreSQL:<br/>{<br/>  "max\_connections"       = "200"<br/>  "effective\_cache\_size"  = "1GB"<br/>}<br/><br/>Example for MySQL:<br/>{<br/>  "max\_connections" = "200"<br/>} | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the RDB instance (the other resources do not take tags).<br/><br/>Scaleway tags are plain strings, by convention "key=value". Duplicates<br/>are removed.<br/><br/>Example: ["environment=production", "team=platform"] | `list(string)` | `[]` | no |
| <a name="input_user_passwords"></a> [user\_passwords](#input\_user\_passwords) | Passwords of the users, keyed like users.<br/><br/>Sent through the write-only password\_wo argument: the values are never<br/>stored in the state or the plan file (OpenTofu/Terraform >= 1.11). Provide<br/>them from an ephemeral source (secrets manager, ephemeral resource) or<br/>TF\_VAR\_user\_passwords. Every key of users needs an entry, and every key<br/>must be a key of users.<br/><br/>Password requirements:<br/>- 8 to 128 characters<br/>- At least one uppercase letter<br/>- At least one lowercase letter<br/>- At least one digit<br/>- At least one special character (!@#$%^&*()\_+-=[]{}\|;:,.<>?) | `map(string)` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | Map of database users to create.<br/><br/>Each user is identified by a unique key used for Terraform resource<br/>addressing. Users are created on the RDB instance and can be granted<br/>privileges on specific databases.<br/><br/>The password of each user comes from user\_passwords, under the same key.<br/>password\_version is the write-only version: bump it to apply a new password.<br/><br/>Example:<br/>{<br/>  app\_user = {<br/>    name     = "app\_service"<br/>    is\_admin = false<br/>  }<br/>  admin\_user = {<br/>    name             = "dba"<br/>    is\_admin         = true<br/>    password\_version = 2<br/>  }<br/>} | <pre>map(object({<br/>    name             = string<br/>    is_admin         = optional(bool, false)<br/>    password_version = optional(number, 1)<br/>  }))</pre> | `{}` | no |
| <a name="input_volume"></a> [volume](#input\_volume) | Storage volume of the database.<br/><br/>- type: lssd (local SSD, fastest, default), sbs\_5k or sbs\_15k (block<br/>  storage with 5,000 or 15,000 IOPS)<br/>- size\_in\_gb: 5 to 10000. Required for sbs\_5k and sbs\_15k, in multiples of 5<br/><br/>Note: bssd is deprecated and no longer supported by Scaleway.<br/><br/>Example: { type = "sbs\_5k", size\_in\_gb = 100 } | <pre>object({<br/>    type       = optional(string, "lssd")<br/>    size_in_gb = optional(number)<br/>  })</pre> | `{}` | no |

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
