# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              INPUT VARIABLES                                  ║
# ║                                                                               ║
# ║  Configurable parameters for Scaleway RDB (Relational Database) management.  ║
# ║  Variables are organized by category with comprehensive validation.          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Organization & Project Configuration
# ==============================================================================

variable "organization_id" {
  description = <<-EOT
    Scaleway Organization ID.

    Required when using project_name to look up the project.
    The organization is the top-level entity in Scaleway's hierarchy.
    Find this in the Scaleway Console under Organization Settings.

    Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.organization_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.organization_id))
    error_message = "Organization ID must be a valid UUID format."
  }
}

variable "project_name" {
  description = <<-EOT
    Scaleway Project name where resources will be created.

    Use this with organization_id to look up the project by name.
    The project ID will be automatically resolved from this name.

    Naming rules:
    - Must start with a lowercase letter
    - Can contain lowercase letters, numbers, and hyphens
    - Must be 1-63 characters long
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.project_name == null || can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.project_name)) || (var.project_name != null && length(var.project_name) == 1 && can(regex("^[a-z]$", var.project_name)))
    error_message = "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 1-63 characters."
  }
}

variable "project_id" {
  description = <<-EOT
    Scaleway Project ID where the RDB instance will be created.

    Either provide project_id directly, or use organization_id + project_name
    to look up the project. If neither is provided, uses the default project
    from provider configuration.

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

variable "engine" {
  description = <<-EOT
    Database engine and version.

    Supported engines:
    - PostgreSQL: PostgreSQL-11, PostgreSQL-12, PostgreSQL-13, PostgreSQL-14, PostgreSQL-15, PostgreSQL-16, PostgreSQL-17
    - MySQL: MySQL-8

    Example: "PostgreSQL-15"
  EOT
  type        = string

  validation {
    condition     = can(regex("^(PostgreSQL-(1[1-7])|MySQL-8)$", var.engine))
    error_message = "Engine must be PostgreSQL-11 through PostgreSQL-17, or MySQL-8."
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

variable "volume_type" {
  description = <<-EOT
    Type of storage volume for the database.

    Available types:
    - lssd: Local SSD (fastest, default)
    - sbs_5k: Block Storage with 5,000 IOPS (scalable, requires volume_size_in_gb)
    - sbs_15k: Block Storage with 15,000 IOPS (scalable, requires volume_size_in_gb)

    Note: sbs_5k and sbs_15k require volume_size_in_gb to be set.
    Note: bssd is deprecated and no longer supported by Scaleway.
  EOT
  type        = string
  default     = "lssd"

  validation {
    condition     = contains(["lssd", "sbs_5k", "sbs_15k"], var.volume_type)
    error_message = "Volume type must be one of: lssd, sbs_5k, sbs_15k. Note: bssd is deprecated."
  }
}

variable "volume_size_in_gb" {
  description = <<-EOT
    Size of the storage volume in gigabytes.

    Required for bssd, sbs_5k, and sbs_15k volume types.
    Must be a multiple of 5 for block storage types.

    Minimum: 5 GB
    Maximum: Varies by node type
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.volume_size_in_gb == null || (var.volume_size_in_gb >= 5 && var.volume_size_in_gb <= 10000)
    error_message = "Volume size must be between 5 and 10000 GB."
  }
}

# ==============================================================================
# Admin User Configuration
# ==============================================================================

variable "admin_user_name" {
  description = <<-EOT
    Username for the initial admin user created with the instance.

    This user has full administrative privileges on the instance.
    Leave null to skip creating an initial admin user.

    Naming rules:
    - Must start with a letter
    - Can contain letters, numbers, and underscores
    - Must be 1-63 characters long
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.admin_user_name == null || can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.admin_user_name))
    error_message = "Admin username must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."
  }
}

variable "admin_user_password" {
  description = <<-EOT
    Password for the initial admin user.

    Required if admin_user_name is set.

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

variable "backup_enabled" {
  description = <<-EOT
    Enable automated backups.

    When enabled, automatic backups are created according to the
    backup_schedule_frequency setting.

    Default: true (strongly recommended for production)
  EOT
  type        = bool
  default     = true
}

variable "backup_schedule_frequency" {
  description = <<-EOT
    Hours between automated backups.

    Only applies when backup_enabled is true.

    Range: 1 to 168 hours (1 week)
    Default: 24 hours (daily backups)
  EOT
  type        = number
  default     = 24

  validation {
    condition     = var.backup_schedule_frequency >= 1 && var.backup_schedule_frequency <= 168
    error_message = "Backup frequency must be between 1 and 168 hours."
  }
}

variable "backup_schedule_retention" {
  description = <<-EOT
    Number of days to retain automated backups.

    Only applies when backup_enabled is true.

    Range: 1 to 365 days
    Default: 14 days
  EOT
  type        = number
  default     = 14

  validation {
    condition     = var.backup_schedule_retention >= 1 && var.backup_schedule_retention <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

variable "backup_same_region" {
  description = <<-EOT
    Store backups in the same region as the instance.

    When false (default), backups are stored in a different region
    for geographic redundancy and disaster recovery.

    Default: false (recommended for production)
  EOT
  type        = bool
  default     = false
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

    Either ip_net or enable_ipam should be set, not both.
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
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = <<-EOT
    Tags to apply to all resources.

    Tags are key-value pairs used for resource organization and filtering.
    They are converted to Scaleway's tag format: "key=value".

    Example:
    {
      environment = "production"
      team        = "platform"
    }
  EOT
  type        = map(string)
  default     = {}
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

    Password requirements:
    - 8 to 128 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character

    Example:
    {
      app_user = {
        name     = "app_service"
        password = "SecureP@ssw0rd!"
        is_admin = false
      }
      admin_user = {
        name     = "dba"
        password = "AdminP@ssw0rd!"
        is_admin = true
      }
    }
  EOT
  type = map(object({
    name     = string
    password = string
    is_admin = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.users : can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", v.name))
    ])
    error_message = "Usernames must start with a letter, contain only letters, numbers, and underscores, and be 1-63 characters."
  }

  validation {
    condition = alltrue([
      for k, v in var.users :
      length(v.password) >= 8 &&
      length(v.password) <= 128 &&
      can(regex("[A-Z]", v.password)) &&
      can(regex("[a-z]", v.password)) &&
      can(regex("[0-9]", v.password)) &&
      can(regex("[!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?]", v.password))
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
    Both the user and database must be created (either via this module
    or the admin user).

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
    Allow unrestricted public access (0.0.0.0/0) in ACL rules.

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
}

# ==============================================================================
# Manual Backups
# ==============================================================================

variable "manual_backups" {
  description = <<-EOT
    Map of manual database backups to create.

    Manual backups are point-in-time exports of specific databases.
    They are independent of the automatic backup schedule.

    Note: Manual backups are only available for instances with
    storage <= 585GB.

    Example:
    {
      app_backup = {
        database_name = "application"
        name          = "pre-migration-backup"
      }
    }
  EOT
  type = map(object({
    database_name = string
    name          = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.manual_backups : can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,62}$", v.name))
    ])
    error_message = "Backup names must start with a letter, contain only letters, numbers, underscores, and hyphens, and be 1-63 characters."
  }
}

# ==============================================================================
# Logs Policy (Optional)
# ==============================================================================

variable "logs_policy" {
  description = <<-EOT
    Configuration for database logs retention and export.

    Controls how long logs are retained and whether they are
    exported to Scaleway Cockpit for centralized monitoring.

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
