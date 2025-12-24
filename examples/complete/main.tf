# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║             COMPLETE EXAMPLE - SCALEWAY RDB MODULE                           ║
# ║                                                                              ║
# ║  Production-ready PostgreSQL setup with:                                     ║
# ║  - High Availability cluster                                                 ║
# ║  - Multiple databases and users                                              ║
# ║  - Granular privileges                                                       ║
# ║  - Read replicas                                                             ║
# ║  - Private network (optional)                                                ║
# ║  - Encryption at rest                                                        ║
# ║  - Comprehensive ACL rules                                                   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Provider Configuration
# ==============================================================================

provider "scaleway" {
  region = "fr-par"
}

# ==============================================================================
# Variables
# ==============================================================================

variable "organization_id" {
  description = "Your Scaleway Organization ID"
  type        = string
}

variable "project_name" {
  description = "Your Scaleway Project name"
  type        = string
  default     = "default"
}

variable "admin_password" {
  description = "Password for the admin user"
  type        = string
  sensitive   = true
  default     = "fs652Af@d$s"
}

variable "app_password" {
  description = "Password for the application user"
  type        = string
  sensitive   = true
  default     = "fs652Af@d$s"
}

variable "readonly_password" {
  description = "Password for the readonly user"
  type        = string
  sensitive   = true
  default     = "fs652Af@d$s"
}

variable "analytics_password" {
  description = "Password for the analytics user"
  type        = string
  sensitive   = true
  default     = "fs652Af@d$s"
}

# ==============================================================================
# RDB Module - Production Configuration
# ==============================================================================

module "production_database" {
  source = "../../"

  # Project configuration
  organization_id = var.organization_id
  project_name    = var.project_name

  # Instance configuration
  name          = "prod-postgres-cluster"
  engine        = "PostgreSQL-16"
  node_type     = "db-gp-s"
  region        = "fr-par"
  is_ha_cluster = true

  # Storage configuration
  volume_type       = "sbs_5k"
  volume_size_in_gb = 100

  # Admin user
  admin_user_name     = "admin"
  admin_user_password = var.admin_password

  # Security
  encryption_at_rest = true

  # Backup configuration
  backup_enabled            = true
  backup_schedule_frequency = 12 # Every 12 hours
  backup_schedule_retention = 30 # 30 days retention
  backup_same_region        = false

  # Engine settings
  settings = {
    max_connections = "200"
  }

  # Logs policy
  logs_policy = {
    max_age_retention    = 30
    total_disk_retention = 100000000
  }

  # Databases
  databases = {
    main = {
      name = "production"
    }
    analytics = {
      name = "analytics"
    }
    staging = {
      name = "staging"
    }
  }

  # Users
  users = {
    app = {
      name     = "app_service"
      password = var.app_password
      is_admin = false
    }
    readonly = {
      name     = "readonly_user"
      password = var.readonly_password
      is_admin = false
    }
    analytics = {
      name     = "analytics_service"
      password = var.analytics_password
      is_admin = false
    }
  }

  # Privileges - Principle of least privilege
  privileges = {
    # App service has full access to production database
    app_production = {
      user_name     = "app_service"
      database_name = "production"
      permission    = "readwrite"
    }
    # App service has full access to staging database
    app_staging = {
      user_name     = "app_service"
      database_name = "staging"
      permission    = "readwrite"
    }
    # Readonly user can only read from production
    readonly_production = {
      user_name     = "readonly_user"
      database_name = "production"
      permission    = "readonly"
    }
    # Analytics service has read access to production
    analytics_production = {
      user_name     = "analytics_service"
      database_name = "production"
      permission    = "readonly"
    }
    # Analytics service has full access to analytics database
    analytics_analytics = {
      user_name     = "analytics_service"
      database_name = "analytics"
      permission    = "readwrite"
    }
  }

  # ACL Rules - Restrict access
  acl_rules = {
    kubernetes_cluster = {
      ip          = "10.0.0.0/8"
      description = "Kubernetes cluster network"
    }
    office_network = {
      ip          = "203.0.113.0/24"
      description = "Office network"
    }
    vpn_network = {
      ip          = "192.168.100.0/24"
      description = "VPN network"
    }
  }

  # Read replicas for read scaling
  # Note: Cross-region replicas require special configuration
  read_replicas = {}

  # Tags
  tags = {
    environment  = "production"
    team         = "platform"
    cost_center  = "engineering"
    managed_by   = "terraform"
    backup_class = "gold"
  }
}

# ==============================================================================
# Outputs
# ==============================================================================

output "instance_id" {
  description = "The RDB instance ID"
  value       = module.production_database.instance_id
}

output "instance_endpoint" {
  description = "Primary database endpoint"
  value = {
    host = module.production_database.connection_host
    port = module.production_database.connection_port
  }
}

output "load_balancer_endpoint" {
  description = "Load balancer endpoint for HA cluster"
  value       = module.production_database.instance_load_balancer
}

output "databases" {
  description = "Created databases"
  value       = module.production_database.databases
}

output "users" {
  description = "Created users (without passwords)"
  value       = module.production_database.users
}

output "privileges" {
  description = "Granted privileges"
  value       = module.production_database.privileges
}

output "read_replicas" {
  description = "Read replica endpoints"
  value       = module.production_database.read_replicas
}

output "encryption_enabled" {
  description = "Whether encryption at rest is enabled"
  value       = module.production_database.encryption_at_rest_enabled
}

output "backup_enabled" {
  description = "Whether automated backups are enabled"
  value       = module.production_database.backup_enabled
}
