# Scaleway Relational Database Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Scaleway Provider][scaleway-badge]][scaleway-url]

A **production-ready** Terraform/OpenTofu module for managing Scaleway Relational Database (RDB) instances with comprehensive security features, high availability support, and flexible configuration options.

## Features

- **Full RDB Resource Support**: Instance, databases, users, privileges, ACLs, read replicas, and backups
- **Security-First Design**: Encryption at rest enabled by default, restrictive ACL validation, sensitive data protection
- **High Availability**: Built-in support for HA clusters with automatic failover
- **Flexible Configuration**: Map-based resources for multiple databases, users, and privileges
- **Comprehensive Validation**: Input validation for all critical fields (UUIDs, CIDRs, passwords, naming conventions)
- **Production Defaults**: Sensible defaults for backups, encryption, and retention policies

## Quick Start

### Prerequisites

- Terraform >= 1.10.7 or OpenTofu >= 1.10.7
- Scaleway account with API credentials configured
- Scaleway provider >= 2.64

### Basic Usage

```hcl
module "database" {
  source = "path/to/scaleway-rdb"

  name      = "my-postgres-db"
  engine    = "PostgreSQL-15"
  node_type = "db-dev-s"
  region    = "fr-par"

  # Admin user
  admin_user_name     = "admin"
  admin_user_password = var.admin_password

  # Create a database
  databases = {
    app = {
      name = "myapp"
    }
  }

  # Create a user
  users = {
    app = {
      name     = "app_user"
      password = var.app_password
      is_admin = false
    }
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

  tags = {
    environment = "production"
  }
}
```

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
  volume_type       = "bssd"
  volume_size_in_gb = 100

  # Security (defaults, shown for clarity)
  encryption_at_rest = true

  # Backup configuration
  backup_enabled            = true
  backup_schedule_frequency = 12  # Every 12 hours
  backup_schedule_retention = 30  # 30 days
  backup_same_region        = false  # Geographic redundancy

  # Admin user
  admin_user_name     = "admin"
  admin_user_password = var.admin_password

  # Multiple databases
  databases = {
    production = { name = "production" }
    analytics  = { name = "analytics" }
  }

  # Multiple users with different roles
  users = {
    app       = { name = "app_service", password = var.app_password, is_admin = false }
    readonly  = { name = "readonly_user", password = var.readonly_password, is_admin = false }
    analytics = { name = "analytics_service", password = var.analytics_password, is_admin = false }
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

  tags = {
    environment = "production"
    team        = "platform"
  }
}
```

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

### Sensitive Data Protection

- All password variables are marked as `sensitive`
- Connection strings and certificates are marked as `sensitive` in outputs
- User passwords are never exposed in outputs

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.7 |
| <a name="requirement_scaleway"></a> [scaleway](#requirement\_scaleway) | ~> 2.64 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_scaleway"></a> [scaleway](#provider\_scaleway) | 2.65.1 |

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
| [scaleway_account_project.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/data-sources/account_project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acl_rules"></a> [acl\_rules](#input\_acl\_rules) | Map of ACL rules to control network access to the RDB instance.<br/><br/>ACL rules define which IP addresses or CIDR ranges can connect<br/>to the database. By default, Scaleway allows all IPs (0.0.0.0/0).<br/>This module requires explicit ACL rules for security.<br/><br/>SECURITY: Do not use 0.0.0.0/0 in production unless absolutely<br/>necessary. Use specific IP ranges or private networks instead.<br/><br/>Example:<br/>{<br/>  office = {<br/>    ip          = "203.0.113.0/24"<br/>    description = "Office network"<br/>  }<br/>  vpn = {<br/>    ip          = "10.0.0.0/8"<br/>    description = "VPN network"<br/>  }<br/>} | <pre>map(object({<br/>    ip          = string<br/>    description = string<br/>  }))</pre> | `{}` | no |
| <a name="input_admin_user_name"></a> [admin\_user\_name](#input\_admin\_user\_name) | Username for the initial admin user created with the instance.<br/><br/>This user has full administrative privileges on the instance.<br/>Leave null to skip creating an initial admin user.<br/><br/>Naming rules:<br/>- Must start with a letter<br/>- Can contain letters, numbers, and underscores<br/>- Must be 1-63 characters long | `string` | `null` | no |
| <a name="input_admin_user_password"></a> [admin\_user\_password](#input\_admin\_user\_password) | Password for the initial admin user.<br/><br/>Required if admin\_user\_name is set.<br/><br/>Password requirements:<br/>- 8 to 128 characters<br/>- At least one uppercase letter<br/>- At least one lowercase letter<br/>- At least one digit<br/>- At least one special character (!@#$%^&*()\_+-=[]{}\|;:,.<>?) | `string` | `null` | no |
| <a name="input_allow_public_access"></a> [allow\_public\_access](#input\_allow\_public\_access) | Allow unrestricted public access (0.0.0.0/0) in ACL rules.<br/><br/>This is a safety flag to prevent accidental exposure of the database<br/>to the public internet. Set to true only if you understand the<br/>security implications.<br/><br/>WARNING: Enabling public access exposes your database to the internet.<br/>Consider using private networks or specific IP allowlists instead.<br/><br/>Default: false | `bool` | `false` | no |
| <a name="input_backup_enabled"></a> [backup\_enabled](#input\_backup\_enabled) | Enable automated backups.<br/><br/>When enabled, automatic backups are created according to the<br/>backup\_schedule\_frequency setting.<br/><br/>Default: true (strongly recommended for production) | `bool` | `true` | no |
| <a name="input_backup_same_region"></a> [backup\_same\_region](#input\_backup\_same\_region) | Store backups in the same region as the instance.<br/><br/>When false (default), backups are stored in a different region<br/>for geographic redundancy and disaster recovery.<br/><br/>Default: false (recommended for production) | `bool` | `false` | no |
| <a name="input_backup_schedule_frequency"></a> [backup\_schedule\_frequency](#input\_backup\_schedule\_frequency) | Hours between automated backups.<br/><br/>Only applies when backup\_enabled is true.<br/><br/>Range: 1 to 168 hours (1 week)<br/>Default: 24 hours (daily backups) | `number` | `24` | no |
| <a name="input_backup_schedule_retention"></a> [backup\_schedule\_retention](#input\_backup\_schedule\_retention) | Number of days to retain automated backups.<br/><br/>Only applies when backup\_enabled is true.<br/><br/>Range: 1 to 365 days<br/>Default: 14 days | `number` | `14` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | Map of databases to create within the RDB instance.<br/><br/>Each database is identified by a unique key used for Terraform resource<br/>addressing. The 'name' field is the actual database name.<br/><br/>Example:<br/>{<br/>  app\_db = {<br/>    name = "application"<br/>  }<br/>  analytics\_db = {<br/>    name = "analytics"<br/>  }<br/>} | <pre>map(object({<br/>    name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_encryption_at_rest"></a> [encryption\_at\_rest](#input\_encryption\_at\_rest) | Enable encryption at rest using LUKS.<br/><br/>When enabled, all data, logs, and snapshots are encrypted at the<br/>storage volume level. Keys are managed by Scaleway.<br/><br/>WARNING: This setting is IRREVERSIBLE once enabled.<br/>WARNING: Initial encryption may take ~1 hour per 100GB of data.<br/><br/>Default: true (recommended for production) | `bool` | `true` | no |
| <a name="input_engine"></a> [engine](#input\_engine) | Database engine and version.<br/><br/>Supported engines:<br/>- PostgreSQL: PostgreSQL-11, PostgreSQL-12, PostgreSQL-13, PostgreSQL-14, PostgreSQL-15, PostgreSQL-16, PostgreSQL-17<br/>- MySQL: MySQL-8<br/><br/>Example: "PostgreSQL-15" | `string` | n/a | yes |
| <a name="input_init_settings"></a> [init\_settings](#input\_init\_settings) | Initial database engine settings applied at creation.<br/><br/>These settings are applied only when the instance is first created<br/>and cannot be changed afterward without recreating the instance.<br/><br/>Use with caution - most settings should go in 'settings' instead. | `map(string)` | `{}` | no |
| <a name="input_is_ha_cluster"></a> [is\_ha\_cluster](#input\_is\_ha\_cluster) | Enable High Availability (HA) mode.<br/><br/>When enabled, creates a standby node with synchronous replication<br/>for automatic failover. Recommended for production workloads.<br/><br/>WARNING: Changing this value will recreate the instance.<br/>WARNING: HA clusters cost approximately 2x a standalone instance.<br/><br/>Default: false | `bool` | `false` | no |
| <a name="input_logs_policy"></a> [logs\_policy](#input\_logs\_policy) | Configuration for database logs retention and export.<br/><br/>Controls how long logs are retained and whether they are<br/>exported to Scaleway Cockpit for centralized monitoring.<br/><br/>Configuration:<br/>- max\_age\_retention: Days to retain logs (1-365)<br/>- total\_disk\_retention: Maximum log size in MB | <pre>object({<br/>    max_age_retention    = optional(number, 30)<br/>    total_disk_retention = optional(number, 100)<br/>  })</pre> | `null` | no |
| <a name="input_manual_backups"></a> [manual\_backups](#input\_manual\_backups) | Map of manual database backups to create.<br/><br/>Manual backups are point-in-time exports of specific databases.<br/>They are independent of the automatic backup schedule.<br/><br/>Note: Manual backups are only available for instances with<br/>storage <= 585GB.<br/><br/>Example:<br/>{<br/>  app\_backup = {<br/>    database\_name = "application"<br/>    name          = "pre-migration-backup"<br/>  }<br/>} | <pre>map(object({<br/>    database_name = string<br/>    name          = string<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the RDB instance.<br/><br/>This is a human-readable identifier for the database instance.<br/>Must be unique within the project.<br/><br/>Naming rules:<br/>- Must start with a letter<br/>- Can contain letters, numbers, and hyphens<br/>- Must be 1-63 characters long | `string` | n/a | yes |
| <a name="input_node_type"></a> [node\_type](#input\_node\_type) | The type of database instance node.<br/><br/>Node type determines CPU, RAM, and performance characteristics.<br/>Available types vary by region.<br/><br/>Common types:<br/>- Development: db-dev-s, db-dev-m, db-dev-l, db-dev-xl<br/>- General Purpose: db-gp-xs, db-gp-s, db-gp-m, db-gp-l, db-gp-xl<br/>- Play2: db-play2-pico, db-play2-nano, db-play2-micro<br/><br/>Example: "db-dev-s" | `string` | n/a | yes |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | Scaleway Organization ID.<br/><br/>Required when using project\_name to look up the project.<br/>The organization is the top-level entity in Scaleway's hierarchy.<br/>Find this in the Scaleway Console under Organization Settings.<br/><br/>Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) | `string` | `null` | no |
| <a name="input_private_network"></a> [private\_network](#input\_private\_network) | Private network configuration for the RDB instance.<br/><br/>Connecting to a private network provides isolated network access<br/>and is recommended for production environments.<br/><br/>Configuration:<br/>- pn\_id: The ID of the private network to connect to<br/>- ip\_net: Static IP address with CIDR notation (e.g., "192.168.1.10/24")<br/>- enable\_ipam: Use Scaleway IPAM for automatic IP assignment<br/><br/>Either ip\_net or enable\_ipam should be set, not both. | <pre>object({<br/>    pn_id       = string<br/>    ip_net      = optional(string)<br/>    enable_ipam = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_privileges"></a> [privileges](#input\_privileges) | Map of user privileges to grant on databases.<br/><br/>Each privilege grants a specific user access to a specific database.<br/>Both the user and database must be created (either via this module<br/>or the admin user).<br/><br/>Permission levels:<br/>- none: No access<br/>- readonly: SELECT queries only<br/>- readwrite: SELECT, INSERT, UPDATE, DELETE<br/>- all: Full access including administrative operations<br/><br/>Example:<br/>{<br/>  app\_on\_appdb = {<br/>    user\_name     = "app\_service"<br/>    database\_name = "application"<br/>    permission    = "readwrite"<br/>  }<br/>  readonly\_on\_analytics = {<br/>    user\_name     = "reporter"<br/>    database\_name = "analytics"<br/>    permission    = "readonly"<br/>  }<br/>} | <pre>map(object({<br/>    user_name     = string<br/>    database_name = string<br/>    permission    = string<br/>  }))</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Scaleway Project ID where the RDB instance will be created.<br/><br/>Either provide project\_id directly, or use organization\_id + project\_name<br/>to look up the project. If neither is provided, uses the default project<br/>from provider configuration.<br/><br/>Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) | `string` | `null` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Scaleway Project name where resources will be created.<br/><br/>Use this with organization\_id to look up the project by name.<br/>The project ID will be automatically resolved from this name.<br/><br/>Naming rules:<br/>- Must start with a lowercase letter<br/>- Can contain lowercase letters, numbers, and hyphens<br/>- Must be 1-63 characters long | `string` | `null` | no |
| <a name="input_read_replicas"></a> [read\_replicas](#input\_read\_replicas) | Map of read replicas to create for read scaling.<br/><br/>Read replicas provide read-only copies of the database for<br/>scaling read-heavy workloads. Data is asynchronously replicated<br/>from the primary instance.<br/><br/>Limits:<br/>- Maximum 3 read replicas per instance<br/>- Read replicas are read-only (cannot write)<br/>- Replication lag may occur<br/><br/>Example:<br/>{<br/>  replica\_1 = {<br/>    region    = "nl-ams"<br/>    same\_zone = false<br/>  }<br/>  replica\_2 = {<br/>    same\_zone = true<br/>    private\_network = {<br/>      pn\_id       = "pn-xxxxx"<br/>      enable\_ipam = true<br/>    }<br/>  }<br/>} | <pre>map(object({<br/>    region    = optional(string)<br/>    same_zone = optional(bool, false)<br/>    private_network = optional(object({<br/>      pn_id       = string<br/>      ip_net      = optional(string)<br/>      enable_ipam = optional(bool, false)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_region"></a> [region](#input\_region) | Scaleway region where the RDB instance will be deployed.<br/><br/>Available regions:<br/>- fr-par: Paris, France<br/>- nl-ams: Amsterdam, Netherlands<br/>- pl-waw: Warsaw, Poland<br/><br/>If not specified, uses the provider's default region. | `string` | `null` | no |
| <a name="input_settings"></a> [settings](#input\_settings) | Database engine configuration settings.<br/><br/>These settings configure the database engine behavior.<br/>Available settings depend on the engine type.<br/><br/>Example for PostgreSQL:<br/>{<br/>  "max\_connections"       = "200"<br/>  "effective\_cache\_size"  = "1GB"<br/>}<br/><br/>Example for MySQL:<br/>{<br/>  "max\_connections" = "200"<br/>} | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources.<br/><br/>Tags are key-value pairs used for resource organization and filtering.<br/>They are converted to Scaleway's tag format: "key=value".<br/><br/>Example:<br/>{<br/>  environment = "production"<br/>  team        = "platform"<br/>} | `map(string)` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | Map of database users to create.<br/><br/>Each user is identified by a unique key used for Terraform resource<br/>addressing. Users are created on the RDB instance and can be granted<br/>privileges on specific databases.<br/><br/>Password requirements:<br/>- 8 to 128 characters<br/>- At least one uppercase letter<br/>- At least one lowercase letter<br/>- At least one digit<br/>- At least one special character<br/><br/>Example:<br/>{<br/>  app\_user = {<br/>    name     = "app\_service"<br/>    password = "SecureP@ssw0rd!"<br/>    is\_admin = false<br/>  }<br/>  admin\_user = {<br/>    name     = "dba"<br/>    password = "AdminP@ssw0rd!"<br/>    is\_admin = true<br/>  }<br/>} | <pre>map(object({<br/>    name     = string<br/>    password = string<br/>    is_admin = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_volume_size_in_gb"></a> [volume\_size\_in\_gb](#input\_volume\_size\_in\_gb) | Size of the storage volume in gigabytes.<br/><br/>Required for bssd, sbs\_5k, and sbs\_15k volume types.<br/>Must be a multiple of 5 for block storage types.<br/><br/>Minimum: 5 GB<br/>Maximum: Varies by node type | `number` | `null` | no |
| <a name="input_volume_type"></a> [volume\_type](#input\_volume\_type) | Type of storage volume for the database.<br/><br/>Available types:<br/>- lssd: Local SSD (fastest, default)<br/>- bssd: Block SSD (scalable, requires volume\_size\_in\_gb)<br/>- sbs\_5k: Block Storage with 5,000 IOPS<br/>- sbs\_15k: Block Storage with 15,000 IOPS<br/><br/>Note: bssd, sbs\_5k, and sbs\_15k require volume\_size\_in\_gb to be set. | `string` | `"lssd"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acl_id"></a> [acl\_id](#output\_acl\_id) | The ID of the ACL resource. |
| <a name="output_acl_rules"></a> [acl\_rules](#output\_acl\_rules) | The ACL rules applied to the instance. |
| <a name="output_admin_password"></a> [admin\_password](#output\_admin\_password) | The admin user password.<br/><br/>Returns the provided password if admin\_user\_password was set,<br/>or the auto-generated password from the instance if not.<br/><br/>WARNING: This is sensitive data - handle with care. |
| <a name="output_backup_enabled"></a> [backup\_enabled](#output\_backup\_enabled) | Whether automated backups are enabled. |
| <a name="output_connection_host"></a> [connection\_host](#output\_connection\_host) | The hostname or IP address for database connections. |
| <a name="output_connection_port"></a> [connection\_port](#output\_connection\_port) | The port for database connections. |
| <a name="output_connection_string"></a> [connection\_string](#output\_connection\_string) | Database connection string.<br/><br/>For PostgreSQL: postgres://user:password@host:port/database?sslmode=require<br/>For MySQL: mysql://user:password@host:port/database<br/><br/>Note: This output requires admin\_user\_name to be set. |
| <a name="output_database_ids"></a> [database\_ids](#output\_database\_ids) | Map of database keys to their IDs. |
| <a name="output_databases"></a> [databases](#output\_databases) | Map of database keys to their full details. |
| <a name="output_encryption_at_rest_enabled"></a> [encryption\_at\_rest\_enabled](#output\_encryption\_at\_rest\_enabled) | Whether encryption at rest is enabled. |
| <a name="output_instance_certificate"></a> [instance\_certificate](#output\_instance\_certificate) | The PEM-encoded TLS certificate for secure connections. |
| <a name="output_instance_endpoint_ip"></a> [instance\_endpoint\_ip](#output\_instance\_endpoint\_ip) | The IP address of the RDB instance endpoint. |
| <a name="output_instance_endpoint_port"></a> [instance\_endpoint\_port](#output\_instance\_endpoint\_port) | The port of the RDB instance endpoint. |
| <a name="output_instance_engine"></a> [instance\_engine](#output\_instance\_engine) | The database engine and version. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | The ID of the RDB instance. |
| <a name="output_instance_is_ha_cluster"></a> [instance\_is\_ha\_cluster](#output\_instance\_is\_ha\_cluster) | Whether the instance is a high availability cluster. |
| <a name="output_instance_load_balancer"></a> [instance\_load\_balancer](#output\_instance\_load\_balancer) | Load balancer endpoint information for the RDB instance. |
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name) | The name of the RDB instance. |
| <a name="output_instance_node_type"></a> [instance\_node\_type](#output\_instance\_node\_type) | The node type of the RDB instance. |
| <a name="output_instance_private_network"></a> [instance\_private\_network](#output\_instance\_private\_network) | Private network endpoint information for the RDB instance. |
| <a name="output_instance_region"></a> [instance\_region](#output\_instance\_region) | The region where the RDB instance is deployed. |
| <a name="output_manual_backups"></a> [manual\_backups](#output\_manual\_backups) | Map of manual backup keys to their details. |
| <a name="output_privileges"></a> [privileges](#output\_privileges) | Map of privilege keys to their details. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The ID of the Scaleway project (resolved from project\_name or provided directly). |
| <a name="output_read_replicas"></a> [read\_replicas](#output\_read\_replicas) | Map of read replica keys to their endpoint information. |
| <a name="output_user_names"></a> [user\_names](#output\_user\_names) | Map of user keys to their usernames (passwords not exposed). |
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
```

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run validation:
   ```bash
   tofu fmt -recursive
   tofu validate
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
[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.10-623CE4
[terraform-url]: https://www.terraform.io
[scaleway-badge]: https://img.shields.io/badge/Scaleway%20Provider-%3E%3D2.64-4f0599
[scaleway-url]: https://registry.terraform.io/providers/scaleway/scaleway/
