# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              INPUT VARIABLES                                  ║
# ║                                                                               ║
# ║  Configurable parameters for Scaleway RDB (Relational Database) management.  ║
# ║  Variables are organized by category with comprehensive validation.          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project Configuration
# ==============================================================================

variable "project_id" {
  description = <<-EOT
    Scaleway Project ID where the RDB instance will be created.

    Leave null to use the default project of the provider configuration.
    The project of the instance is exposed by the project_id output.

    Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.project_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.project_id))
    error_message = "Project ID must be a valid UUID format."
  }
}

# ==============================================================================
# Instance Configuration
# ==============================================================================

variable "name" {
  description = <<-EOT
    Name of the RDB instance.

    This is a human-readable identifier for the database instance.
    Must be unique within the project.

    Naming rules:
    - Must start with a letter
    - Can contain letters, numbers, and hyphens
    - Must be 1-63 characters long
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,62}$", var.name))
    error_message = "Instance name must start with a letter, contain only letters, numbers, and hyphens, and be 1-63 characters."
  }
}

variable "node_type" {
  description = <<-EOT
    The type of database instance node.

    Node type determines CPU, RAM, and performance characteristics.
    Available types vary by region.

    Common types:
    - Development: db-dev-s, db-dev-m, db-dev-l, db-dev-xl
    - General Purpose: db-gp-xs, db-gp-s, db-gp-m, db-gp-l, db-gp-xl
    - Play2: db-play2-pico, db-play2-nano, db-play2-micro

    Example: "db-dev-s"
  EOT
  type        = string

  validation {
    condition     = can(regex("^db-(dev|gp|play2)-", var.node_type))
    error_message = "Node type must start with 'db-dev-', 'db-gp-', or 'db-play2-'."
  }
}

variable "engine" {
  description = <<-EOT
    Database engine and version.

    Set exactly one of engine or clone_from. With clone_from, leave engine null:
    the clone has the engine of its source.

    Supported engines:
    - PostgreSQL: PostgreSQL-11, PostgreSQL-12, PostgreSQL-13, PostgreSQL-14, PostgreSQL-15, PostgreSQL-16, PostgreSQL-17
    - MySQL: MySQL-8

    Example: "PostgreSQL-15"

    Engine upgrade: changing the version of an existing instance runs a blue/green
    upgrade in the provider. Writes made between the snapshot and the switch are
    lost, scaleway_rdb_acl may need a second apply because it uses the instance ID,
    and the apply must never be re-run while an upgrade is in progress.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.engine == null || can(regex("^(PostgreSQL-(1[1-7])|MySQL-8)$", var.engine))
    error_message = "Engine must be PostgreSQL-11 through PostgreSQL-17, or MySQL-8."
  }
}

variable "clone_from" {
  description = <<-EOT
    Create the instance as a clone of an existing Database Instance.

    Accepts the instance UUID or <region>/<UUID>. The clone keeps the databases, users and
    permissions of the source; declare in databases, users and privileges only new ones
    (an existing name fails at apply with an API conflict). Provider 2.89.0 or later.

    Rules:
    - Leave engine null: the clone has the engine of the source.
    - Leave admin_user and admin_user_password null: the clone keeps the users of the source.
    - volume.type, volume.size_in_gb (block storage), encryption_at_rest and init_settings are not
      applied at clone time and must equal the source values (checked at plan time).
    - A high-availability source needs is_ha_cluster = true.
    - project_id is not applied: the clone stays in the project of the source.
    - Without private_network the clone keeps the public endpoint created by the clone;
      with it the clone is private unless public_endpoint is true.

    WARNING: Setting this value on an existing instance will recreate the instance.

    Example: "fr-par/11111111-2222-3333-4444-555555555555"
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.clone_from == null || can(regex("^([a-z]{2}-[a-z]{3}/)?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.clone_from))
    error_message = "clone_from must be an instance UUID or <region>/<UUID> (the instance_id format)."
  }
}

variable "region" {
  description = <<-EOT
    Scaleway region where the RDB instance will be deployed.

    Available regions:
    - fr-par: Paris, France
    - nl-ams: Amsterdam, Netherlands
    - pl-waw: Warsaw, Poland

    If not specified, uses the provider's default region.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.region == null || contains(["fr-par", "nl-ams", "pl-waw"], var.region)
    error_message = "Region must be one of: fr-par, nl-ams, pl-waw."
  }
}

variable "is_ha_cluster" {
  description = <<-EOT
    Enable High Availability (HA) mode.

    When enabled, creates a standby node with synchronous replication
    for automatic failover. Recommended for production workloads.

    WARNING: Changing this value will recreate the instance.
    WARNING: HA clusters cost approximately 2x a standalone instance.

    Default: false
  EOT
  type        = bool
  default     = false
}

variable "volume" {
  description = <<-EOT
    Storage volume of the database.

    - type: lssd (local SSD, fastest, default), sbs_5k or sbs_15k (block
      storage with 5,000 or 15,000 IOPS)
    - size_in_gb: 5 to 10000. Required for sbs_5k and sbs_15k, in multiples of 5

    Note: bssd is deprecated and no longer supported by Scaleway.

    Example: { type = "sbs_5k", size_in_gb = 100 }
  EOT
  type = object({
    type       = optional(string, "lssd")
    size_in_gb = optional(number)
  })
  default = {}

  validation {
    condition     = contains(["lssd", "sbs_5k", "sbs_15k"], var.volume.type)
    error_message = "Volume type must be one of: lssd, sbs_5k, sbs_15k. Note: bssd is deprecated."
  }

  validation {
    condition     = var.volume.size_in_gb == null || (var.volume.size_in_gb >= 5 && var.volume.size_in_gb <= 10000)
    error_message = "Volume size must be between 5 and 10000 GB."
  }
}

# ==============================================================================
# Admin User Configuration
# ==============================================================================

variable "admin_user" {
  description = <<-EOT
    Initial admin user created with the instance.

    - name: user name, with full administrative privileges on the instance
    - password_version: version of the write-only password; bump it to apply a
      new admin_user_password (default 1)

    Set together with admin_user_password, or leave both null to skip the
    initial admin user.

    Naming rules:
    - Must start with a letter
    - Can contain letters, numbers, and underscores
    - Must be 1-63 characters long

    Example: { name = "admin" }
  EOT
  type = object({
    name             = string
    password_version = optional(number, 1)
  })
  default = null

  validation {
    condition     = var.admin_user == null || can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.admin_user.name))
    error_message = "Admin username must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."
  }
}

variable "admin_user_password" {
  description = <<-EOT
    Password of the initial admin user (admin_user).

    Sent through the write-only password_wo argument: never stored in the
    state or the plan file (OpenTofu/Terraform >= 1.11). Provide it from an
    ephemeral source (secrets manager, ephemeral resource) or
    TF_VAR_admin_user_password. Bump admin_user.password_version to apply a
    new value.

    Password requirements:
    - 8 to 128 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character (!@#$%^&*()_+-=[]{}|;:,.<>?)
  EOT
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true

  validation {
    condition = var.admin_user_password == null || (
      length(var.admin_user_password) >= 8 &&
      length(var.admin_user_password) <= 128 &&
      can(regex("[A-Z]", var.admin_user_password)) &&
      can(regex("[a-z]", var.admin_user_password)) &&
      can(regex("[0-9]", var.admin_user_password)) &&
      can(regex("[!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?]", var.admin_user_password))
    )
    error_message = "Password must be 8-128 characters with at least one uppercase, lowercase, digit, and special character."
  }
}

# ==============================================================================
# Security Configuration
# ==============================================================================

variable "encryption_at_rest" {
  description = <<-EOT
    Enable encryption at rest using LUKS.

    When enabled, all data, logs, and snapshots are encrypted at the
    storage volume level. Keys are managed by Scaleway.

    WARNING: This setting is IRREVERSIBLE once enabled.
    WARNING: Initial encryption may take ~1 hour per 100GB of data.

    Default: true (recommended for production)
  EOT
  type        = bool
  default     = true
}

# ==============================================================================
# Backup Configuration
# ==============================================================================

variable "backup" {
  description = <<-EOT
    Automated backup settings.

    - enabled: create automated backups (default true, strongly recommended for production)
    - frequency_hours: hours between backups, 1 to 168 (default 24)
    - retention_days: days to keep backups, 1 to 365 (default 14)
    - same_region: store backups in the region of the instance; false (default)
      stores them in another region for geographic redundancy

    frequency_hours, retention_days and same_region apply only when enabled is true.

    Example: { frequency_hours = 12, retention_days = 30 }
  EOT
  type = object({
    enabled         = optional(bool, true)
    frequency_hours = optional(number, 24)
    retention_days  = optional(number, 14)
    same_region     = optional(bool, false)
  })
  default = {}

  validation {
    condition     = var.backup.frequency_hours >= 1 && var.backup.frequency_hours <= 168
    error_message = "Backup frequency must be between 1 and 168 hours."
  }

  validation {
    condition     = var.backup.retention_days >= 1 && var.backup.retention_days <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

# ==============================================================================
# Engine Settings
# ==============================================================================

variable "settings" {
  description = <<-EOT
    Database engine configuration settings.

    These settings configure the database engine behavior.
    Available settings depend on the engine type.

    Example for PostgreSQL:
    {
      "max_connections"       = "200"
      "effective_cache_size"  = "1GB"
    }

    Example for MySQL:
    {
      "max_connections" = "200"
    }
  EOT
  type        = map(string)
  default     = {}
}

variable "init_settings" {
  description = <<-EOT
    Initial database engine settings applied at creation.

    These settings are applied only when the instance is first created
    and cannot be changed afterward without recreating the instance.

    Use with caution - most settings should go in 'settings' instead.
  EOT
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Private Network Configuration
# ==============================================================================

variable "private_network" {
  description = <<-EOT
    Private network configuration for the RDB instance.

    Connecting to a private network provides isolated network access
    and is recommended for production environments.

    Configuration:
    - pn_id: The ID of the private network to connect to
    - ip_net: Static IP address with CIDR notation (e.g., "192.168.1.10/24")
    - enable_ipam: Use Scaleway IPAM for automatic IP assignment

    Set exactly one of ip_net or enable_ipam = true: both together and
    neither are rejected (the provider fails at apply without one).
  EOT
  type = object({
    pn_id       = string
    ip_net      = optional(string)
    enable_ipam = optional(bool, false)
  })
  default = null

  validation {
    condition = var.private_network == null || (
      var.private_network.ip_net == null ||
      can(cidrhost(var.private_network.ip_net, 0))
    )
    error_message = "ip_net must be a valid CIDR notation (e.g., '192.168.1.10/24')."
  }

  validation {
    condition = var.private_network == null || !(
      var.private_network.ip_net != null && var.private_network.enable_ipam == true
    )
    error_message = "Cannot set both ip_net and enable_ipam. Use one or the other."
  }

  validation {
    condition = var.private_network == null || (
      var.private_network.ip_net != null || var.private_network.enable_ipam == true
    )
    error_message = "Set either ip_net or enable_ipam = true."
  }
}

variable "public_endpoint" {
  description = <<-EOT
    Keep a public endpoint next to the private network.

    Only with private_network: the instance then answers on both the private
    network and a public endpoint (reach it through acl_rules). Leave false
    for a private-only instance. Without private_network the instance is
    always public and this must stay false.

    Default: false
  EOT
  type        = bool
  default     = false
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = <<-EOT
    Tags to apply to the RDB instance (the other resources do not take tags).

    Scaleway tags are plain strings, by convention "key=value". Duplicates
    are removed.

    Example: ["environment=production", "team=platform"]
  EOT
  type        = list(string)
  default     = []
}

# ==============================================================================
# Databases
# ==============================================================================

variable "databases" {
  description = <<-EOT
    Map of databases to create within the RDB instance.

    Each database is identified by a unique key used for Terraform resource
    addressing. The 'name' field is the actual database name.

    Example:
    {
      app_db = {
        name = "application"
      }
      analytics_db = {
        name = "analytics"
      }
    }
  EOT
  type = map(object({
    name = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.databases : can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", v.name))
    ])
    error_message = "Database names must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."
  }
}

# ==============================================================================
# Users
# ==============================================================================

variable "users" {
  description = <<-EOT
    Map of database users to create.

    Each user is identified by a unique key used for Terraform resource
    addressing. Users are created on the RDB instance and can be granted
    privileges on specific databases.

    The password of each user comes from user_passwords, under the same key.
    password_version is the write-only version: bump it to apply a new password.

    Example:
    {
      app_user = {
        name     = "app_service"
        is_admin = false
      }
      admin_user = {
        name             = "dba"
        is_admin         = true
        password_version = 2
      }
    }
  EOT
  type = map(object({
    name             = string
    is_admin         = optional(bool, false)
    password_version = optional(number, 1)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.users : can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", v.name))
    ])
    error_message = "Usernames must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."
  }
}

variable "user_passwords" {
  description = <<-EOT
    Passwords of the users, keyed like users.

    Sent through the write-only password_wo argument: the values are never
    stored in the state or the plan file (OpenTofu/Terraform >= 1.11). Provide
    them from an ephemeral source (secrets manager, ephemeral resource) or
    TF_VAR_user_passwords. Every key of users needs an entry, and every key
    must be a key of users.

    Password requirements:
    - 8 to 128 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character (!@#$%^&*()_+-=[]{}|;:,.<>?)
  EOT
  type        = map(string)
  default     = {}
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = alltrue([for k in keys(var.user_passwords) : contains(keys(var.users), k)])
    error_message = "user_passwords keys must be keys of users."
  }

  validation {
    condition = alltrue([
      for p in values(var.user_passwords) :
      length(p) >= 8 &&
      length(p) <= 128 &&
      can(regex("[A-Z]", p)) &&
      can(regex("[a-z]", p)) &&
      can(regex("[0-9]", p)) &&
      can(regex("[!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?]", p))
    ])
    error_message = "User passwords must be 8-128 characters with at least one uppercase, lowercase, digit, and special character."
  }
}

# ==============================================================================
# Privileges
# ==============================================================================

variable "privileges" {
  description = <<-EOT
    Map of user privileges to grant on databases.

    Each privilege grants a specific user access to a specific database.
    Both the user and database must exist (created via this module, as the
    admin user, or outside the module). The names are not cross-checked
    against users and databases: a wrong name fails at apply.

    Permission levels:
    - none: No access
    - readonly: SELECT queries only
    - readwrite: SELECT, INSERT, UPDATE, DELETE
    - all: Full access including administrative operations

    Example:
    {
      app_on_appdb = {
        user_name     = "app_service"
        database_name = "application"
        permission    = "readwrite"
      }
      readonly_on_analytics = {
        user_name     = "reporter"
        database_name = "analytics"
        permission    = "readonly"
      }
    }
  EOT
  type = map(object({
    user_name     = string
    database_name = string
    permission    = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.privileges : contains(["none", "readonly", "readwrite", "all"], v.permission)
    ])
    error_message = "Permission must be one of: none, readonly, readwrite, all."
  }
}

# ==============================================================================
# ACL Rules
# ==============================================================================

variable "acl_rules" {
  description = <<-EOT
    Map of ACL rules to control network access to the RDB instance.

    ACL rules define which IP addresses or CIDR ranges can connect
    to the database. By default, Scaleway allows all IPs (0.0.0.0/0).
    This module requires explicit ACL rules for security.

    SECURITY: Do not use 0.0.0.0/0 in production unless absolutely
    necessary. Use specific IP ranges or private networks instead.
    0.0.0.0/0 is rejected unless allow_public_access is true; other very
    wide ranges (prefix shorter than /8, such as 0.0.0.0/1) only raise a
    plan-time warning. The Scaleway API does not support IPv6 ACL rules.

    Example:
    {
      office = {
        ip          = "203.0.113.0/24"
        description = "Office network"
      }
      vpn = {
        ip          = "10.0.0.0/8"
        description = "VPN network"
      }
    }
  EOT
  type = map(object({
    ip          = string
    description = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.acl_rules : can(cidrhost(v.ip, 0))
    ])
    error_message = "ACL rule IP must be a valid CIDR notation (e.g., '192.168.1.0/24' or '10.0.0.1/32')."
  }
}

variable "allow_public_access" {
  description = <<-EOT
    Allow unrestricted public access (0.0.0.0/0) in ACL rules and silence
    the warning about other very wide ranges.

    This is a safety flag to prevent accidental exposure of the database
    to the public internet. Set to true only if you understand the
    security implications.

    WARNING: Enabling public access exposes your database to the internet.
    Consider using private networks or specific IP allowlists instead.

    Default: false
  EOT
  type        = bool
  default     = false
}

# ==============================================================================
# Read Replicas
# ==============================================================================

variable "read_replicas" {
  description = <<-EOT
    Map of read replicas to create for read scaling.

    Read replicas provide read-only copies of the database for
    scaling read-heavy workloads. Data is asynchronously replicated
    from the primary instance.

    Limits:
    - Maximum 3 read replicas per instance
    - Read replicas are read-only (cannot write)
    - Replication lag may occur

    Example:
    {
      replica_1 = {
        region    = "nl-ams"
        same_zone = false
      }
      replica_2 = {
        same_zone = true
        private_network = {
          pn_id       = "pn-xxxxx"
          enable_ipam = true
        }
      }
    }
  EOT
  type = map(object({
    region    = optional(string)
    same_zone = optional(bool, false)
    private_network = optional(object({
      pn_id       = string
      ip_net      = optional(string)
      enable_ipam = optional(bool, false)
    }))
  }))
  default = {}

  validation {
    condition     = length(var.read_replicas) <= 3
    error_message = "Maximum 3 read replicas are allowed per instance."
  }

  validation {
    condition = alltrue([
      for k, v in var.read_replicas :
      v.region == null || contains(["fr-par", "nl-ams", "pl-waw"], v.region)
    ])
    error_message = "Read replica region must be one of: fr-par, nl-ams, pl-waw."
  }

  validation {
    condition = alltrue([
      for k, v in var.read_replicas :
      v.private_network == null || v.private_network.ip_net == null || can(cidrhost(v.private_network.ip_net, 0))
    ])
    error_message = "Read replica ip_net must be a valid CIDR notation (e.g., '192.168.1.10/24')."
  }

  validation {
    condition = alltrue([
      for k, v in var.read_replicas :
      v.private_network == null || v.private_network.ip_net != null || v.private_network.enable_ipam == true
    ])
    error_message = "Read replica private_network needs ip_net or enable_ipam = true."
  }
}

# ==============================================================================
# Manual Backups
# ==============================================================================

variable "manual_backups" {
  description = <<-EOT
    Map of manual database backups to create.

    Manual backups are point-in-time exports of specific databases.
    They are independent of the automatic backup schedule.

    expires_at (optional) is the expiry of the backup, a UTC timestamp written
    YYYY-MM-DDTHH:MM:SSZ. Without it the backup never expires and is billed until
    deleted. The provider cannot remove an expiry once set.

    Note: Manual backups are only available for instances with
    storage <= 585GB; a plan-time warning is raised when volume.size_in_gb
    is larger. database_name is not cross-checked against databases.

    Example:
    {
      app_backup = {
        database_name = "application"
        name          = "pre-migration-backup"
        expires_at    = "2027-01-31T00:00:00Z"
      }
    }
  EOT
  type = map(object({
    database_name = string
    name          = string
    expires_at    = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.manual_backups : can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,62}$", v.name))
    ])
    error_message = "Backup names must start with a letter, contain only letters, numbers, underscores, and hyphens, and be 1-63 characters."
  }

  validation {
    condition = alltrue([
      for k, v in var.manual_backups : v.expires_at == null || (
        can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", v.expires_at)) &&
        can(timeadd(v.expires_at, "0s"))
      )
    ])
    error_message = "expires_at must be a UTC timestamp like 2027-01-31T00:00:00Z."
  }
}

# ==============================================================================
# Logs Policy (Optional)
# ==============================================================================

variable "logs_policy" {
  description = <<-EOT
    Configuration for database logs retention.

    Controls how long logs are retained and how much disk they may use.

    Configuration:
    - max_age_retention: Days to retain logs (1-365)
    - total_disk_retention: Maximum log storage in bytes (minimum 100000000 = 100MB)
  EOT
  type = object({
    max_age_retention    = optional(number, 30)
    total_disk_retention = optional(number, 100000000)
  })
  default = null

  validation {
    condition = var.logs_policy == null || (
      var.logs_policy.max_age_retention >= 1 &&
      var.logs_policy.max_age_retention <= 365
    )
    error_message = "max_age_retention must be between 1 and 365 days."
  }

  validation {
    condition = var.logs_policy == null || (
      var.logs_policy.total_disk_retention >= 100000000
    )
    error_message = "total_disk_retention must be at least 100000000 bytes (100MB)."
  }
}
