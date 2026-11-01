# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║              MINIMAL EXAMPLE - SCALEWAY RDB MODULE                           ║
# ║                                                                              ║
# ║  Basic PostgreSQL database with single database and user.                    ║
# ║  Demonstrates minimum required configuration for production use.             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Provider Configuration
# ==============================================================================

provider "scaleway" {
  region = "fr-par"
}

# ==============================================================================
# RDB Module
# ==============================================================================

module "database" {
  source = "../../"

  # Instance configuration
  name      = "my-postgres-db"
  engine    = "PostgreSQL-15"
  node_type = "db-dev-s"
  region    = "fr-par"

  # Admin user
  admin_user          = { name = "admin" }
  admin_user_password = var.admin_password

  # Security defaults (already enabled by default, shown for clarity)
  encryption_at_rest = true

  # Backup configuration
  backup = {
    enabled         = true
    frequency_hours = 24 # Daily backups
    retention_days  = 14 # Keep for 2 weeks
    same_region     = false
  }

  # Create a database
  databases = {
    app = {
      name = "myapp"
    }
  }

  # Create a non-admin user for the application
  users = {
    app = {
      name     = "app_user"
      is_admin = false
    }
  }

  # Passwords of the users, keyed like users (write-only, never stored in state)
  user_passwords = {
    app = var.app_user_password
  }

  # Grant permissions
  privileges = {
    app_on_myapp = {
      user_name     = "app_user"
      database_name = "myapp"
      permission    = "readwrite"
    }
  }

  # ACL - Allow from specific IP only
  acl_rules = {
    my_ip = {
      ip          = var.allowed_ip
      description = "My development machine"
    }
  }

  # Tags
  tags = ["environment=development", "managed_by=terraform"]
}

# ==============================================================================
# Variables
# ==============================================================================

variable "admin_password" {
  description = "Password for the admin user (8-128 chars, uppercase, lowercase, digit, special char; set TF_VAR_admin_password, never stored in state or plan)"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "app_user_password" {
  description = "Password for the application user (set TF_VAR_app_user_password, never stored in state or plan)"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "allowed_ip" {
  description = "IP address allowed to connect (CIDR notation, e.g., 203.0.113.50/32)"
  type        = string
  # No default - must be explicitly provided for security
}

# ==============================================================================
# Outputs
# ==============================================================================

output "instance_id" {
  description = "The RDB instance ID"
  value       = module.database.instance_id
}

output "connection_host" {
  description = "Database connection host"
  value       = module.database.connection_host
}

output "connection_port" {
  description = "Database connection port"
  value       = module.database.connection_port
}

output "database_name" {
  description = "The created database name"
  value       = module.database.databases["app"].name
}
