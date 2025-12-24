# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              INPUT VARIABLES                                  ║
# ║                                                                               ║
# ║  Configurable parameters for Scaleway DNS Zone and Record management.        ║
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
    condition     = var.project_name == null || can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.project_name)) || (var.project_name != null && length(var.project_name) == 1)
    error_message = "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 1-63 characters."
  }
}

variable "project_id" {
  description = <<-EOT
    Scaleway Project ID where the DNS zone will be created.

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



variable "name" {
  type        = string
  description = "The name of the Redis cluster"
}

variable "tags" {
  type = map(any)
}

variable "region" {
  type = string
}

variable "username" {
  type = string
}
variable "password" {
  type = string
}

variable "node_type" {
  type = string
}

variable "cluster_mode" {
  type = string
}
variable "postgres_engine" {
  type = string
}
variable "backups" {
  type = object({
    enabled        = bool
    retention_days = optional(number)
    frequency_days = optional(number)
  })
}

variable "database_name" {
  type        = string
  description = "The name of database"
}
