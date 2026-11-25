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
  description = "Scaleway Project ID (UUID) in which the RDB instance is created. `null` uses the default project of the provider configuration; the project actually used is exposed by the `project_id` output."
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
  description = "Name of the RDB instance, unique within the project. Must start with a letter, contain only letters, numbers and hyphens, and be 1 to 63 characters long."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,62}$", var.name))
    error_message = "Instance name must start with a letter, contain only letters, numbers, and hyphens, and be 1-63 characters."
  }
}

variable "node_type" {
  description = "Node type of the database instance, which sets its CPU, RAM and performance (for example `db-dev-s`, `db-gp-xs` or `db-play2-pico`). Must start with `db-dev-`, `db-gp-` or `db-play2-`; availability varies by region. See Input reference in the README for the common types."
  type        = string

  validation {
    condition     = can(regex("^db-(dev|gp|play2)-", var.node_type))
    error_message = "Node type must start with 'db-dev-', 'db-gp-', or 'db-play2-'."
  }
}

variable "engine" {
  description = "Database engine and version, for example `PostgreSQL-15` or `MySQL-8` (PostgreSQL-11 to PostgreSQL-17, MySQL-8). Set exactly one of `engine` or `clone_from`; `null` is only valid with `clone_from`, the clone then has the engine of its source. See Input reference in the README for the engine upgrade behaviour."
  type        = string
  default     = null

  validation {
    condition     = var.engine == null || can(regex("^(PostgreSQL-(1[1-7])|MySQL-8)$", var.engine))
    error_message = "Engine must be PostgreSQL-11 through PostgreSQL-17, or MySQL-8."
  }
}

variable "clone_from" {
  description = "Creates the instance as a clone of an existing Database Instance, given as its UUID or `<region>/<UUID>`; `null` creates a new instance. Setting it on an existing instance recreates the instance. See Input reference in the README for the rules that apply to a clone."
  type        = string
  default     = null

  validation {
    condition     = var.clone_from == null || can(regex("^([a-z]{2}-[a-z]{3}/)?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.clone_from))
    error_message = "clone_from must be an instance UUID or <region>/<UUID> (the instance_id format)."
  }
}

variable "region" {
  description = "Scaleway region in which the RDB instance is deployed: `fr-par`, `nl-ams` or `pl-waw`. `null` uses the region of the provider configuration."
  type        = string
  default     = null

  validation {
    condition     = var.region == null || contains(["fr-par", "nl-ams", "pl-waw"], var.region)
    error_message = "Region must be one of: fr-par, nl-ams, pl-waw."
  }
}

variable "is_ha_cluster" {
  description = "Enables High Availability: a standby node with synchronous replication for automatic failover, recommended for production. Changing it recreates the instance and an HA cluster costs about twice a standalone instance."
  type        = bool
  default     = false
}

variable "volume" {
  description = "Storage volume of the database: `type` is `lssd` (local SSD, default), `sbs_5k` or `sbs_15k` (block storage with 5,000 or 15,000 IOPS) and `size_in_gb` is 5 to 10000. See Input reference in the README for every attribute."
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
  description = "Initial admin user created with the instance, with full administrative privileges: `name` and an optional `password_version` (default 1) that is bumped to apply a new `admin_user_password`. Set it together with `admin_user_password`, or leave both `null` to skip the initial admin user. See Input reference in the README for the naming rules."
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
  description = "Password of the initial admin user (`admin_user`), sent through the write-only `password_wo` argument so it never lands in the state or the plan (OpenTofu/Terraform 1.11 or later). Provide it from an ephemeral source or `TF_VAR_admin_user_password`; bump `admin_user.password_version` to apply a new value. See Input reference in the README for the password requirements."
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
  description = "Enables LUKS encryption at rest of the data, logs and snapshots, with keys managed by Scaleway; recommended for production. It is irreversible once enabled and the initial encryption takes about 1 hour per 100 GB of data."
  type        = bool
  default     = true
}

# ==============================================================================
# Backup Configuration
# ==============================================================================

variable "backup" {
  description = "Automated backup settings: `enabled` (default `true`), `frequency_hours` (1 to 168, default 24), `retention_days` (1 to 365, default 14) and `same_region` (default `false`, which stores backups in another region). See Input reference in the README for every attribute."
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
  description = "Database engine settings as a map of strings, for example `max_connections` set to `200`. The available settings depend on the engine."
  type        = map(string)
  default     = {}
}

variable "init_settings" {
  description = "Engine settings applied only when the instance is first created; they cannot be changed afterwards without recreating the instance. Most settings belong in `settings` instead."
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Private Network Configuration
# ==============================================================================

variable "private_network" {
  description = "Private network of the RDB instance: `pn_id` is the private network ID and exactly one of `ip_net` (static IP in CIDR notation) or `enable_ipam = true` must be set. `null` keeps the instance on its public endpoint. See Input reference in the README for every attribute."
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
  description = "Keeps a public endpoint next to the private network, reachable through `acl_rules`. Only valid with `private_network`; without it the instance is always public and this must stay `false`, which gives a private-only instance."
  type        = bool
  default     = false
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Tags applied to the RDB instance, the only resource of the module that takes tags. Tags are plain strings, by convention `key=value`, and duplicates are removed."
  type        = list(string)
  default     = []
}

# ==============================================================================
# Databases
# ==============================================================================

variable "databases" {
  description = "Map of databases to create in the RDB instance, keyed by a stable reference used for resource addressing; each entry sets the database `name`. See Input reference in the README for every attribute."
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
  description = "Map of database users to create, keyed by a stable reference that is also the key of the user password in `user_passwords`. Each entry sets `name`, `is_admin` and `password_version`. See Input reference in the README for every attribute."
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
  description = "Passwords of the database users, keyed like `users`, sent through the write-only `password_wo` argument so they never land in the state or the plan (OpenTofu/Terraform 1.11 or later). Every key of `users` needs an entry and every key must be a key of `users`; provide them from an ephemeral source or `TF_VAR_user_passwords`. See Input reference in the README for the password requirements."
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
  description = "Map of privileges granted to users on databases, keyed by a stable reference. Each entry sets `user_name`, `database_name` and `permission` (`none`, `readonly`, `readwrite` or `all`). See Input reference in the README for every attribute."
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
  description = "Map of ACL rules that control which IPv4 addresses or CIDR ranges can connect to the instance, keyed by a stable reference. Each entry sets `ip` and `description`; `0.0.0.0/0` is rejected unless `allow_public_access` is `true`. See Input reference in the README for every attribute and the security notes."
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
  description = "Safety flag that allows unrestricted public access (`0.0.0.0/0`) in `acl_rules` and silences the warning about other very wide ranges. Enabling it exposes the database to the internet, so prefer private networks or specific IP allowlists."
  type        = bool
  default     = false
}

# ==============================================================================
# Read Replicas
# ==============================================================================

variable "read_replicas" {
  description = "Map of read replicas (at most 3), keyed by a stable reference. Each entry sets an optional `region`, `same_zone` and an optional `private_network`. See Input reference in the README for every attribute."
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
  description = "Map of manual database backups to create, keyed by a stable reference. Each entry sets `database_name`, `name` and an optional `expires_at` UTC timestamp. See Input reference in the README for every attribute."
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
  description = "Retention of the database logs: `max_age_retention` in days (1 to 365, default 30) and `total_disk_retention` in bytes (at least 100000000, default 100000000). `null` keeps the provider default. See Input reference in the README for every attribute."
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
