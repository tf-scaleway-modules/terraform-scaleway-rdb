# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              MODULE OUTPUTS                                  ║
# ║                                                                              ║
# ║  Outputs for RDB instance, databases, users, and related resources.         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Instance Outputs
# ==============================================================================

output "project_id" {
  description = "The ID of the Scaleway project of the instance (the provider default project when the project_id input is null)."
  value       = scaleway_rdb_instance.this.project_id
}

output "instance_id" {
  description = "The ID of the RDB instance."
  value       = scaleway_rdb_instance.this.id
}

output "instance_region" {
  description = "The region where the RDB instance is deployed."
  value       = scaleway_rdb_instance.this.region
}

output "instance_engine" {
  description = "The database engine and version."
  value       = scaleway_rdb_instance.this.engine
}

output "instance_certificate" {
  description = "The PEM-encoded TLS certificate for secure connections."
  value       = scaleway_rdb_instance.this.certificate
  sensitive   = true
}

output "instance_load_balancer" {
  description = "Public (load balancer) endpoint of the RDB instance, null when it has none."
  value = try({
    ip       = scaleway_rdb_instance.this.load_balancer[0].ip
    port     = scaleway_rdb_instance.this.load_balancer[0].port
    name     = scaleway_rdb_instance.this.load_balancer[0].name
    hostname = scaleway_rdb_instance.this.load_balancer[0].hostname
  }, null)
}

output "instance_private_network" {
  description = "Private network endpoint of the RDB instance, null when it has none."
  value = try({
    ip       = scaleway_rdb_instance.this.private_network[0].ip
    port     = scaleway_rdb_instance.this.private_network[0].port
    hostname = scaleway_rdb_instance.this.private_network[0].hostname
  }, null)
}

output "connection_host" {
  description = "The IP address for database connections: the public endpoint, or the private network endpoint when there is none."
  value       = try(scaleway_rdb_instance.this.load_balancer[0].ip, scaleway_rdb_instance.this.private_network[0].ip, null)
}

output "connection_port" {
  description = "The port for database connections: the public endpoint, or the private network endpoint when there is none."
  value       = try(scaleway_rdb_instance.this.load_balancer[0].port, scaleway_rdb_instance.this.private_network[0].port, null)
}

output "engine_type" {
  description = "The detected engine type (postgresql or mysql)."
  value       = local.is_postgresql ? "postgresql" : "mysql"
}

output "engine_default_port" {
  description = "The default port for the database engine (5432 for PostgreSQL, 3306 for MySQL)."
  value       = local.is_postgresql ? 5432 : 3306
}

# ==============================================================================
# Database Outputs
# ==============================================================================

output "databases" {
  description = "Map of database keys to their details."
  value = {
    for k, v in scaleway_rdb_database.this : k => {
      id          = v.id
      name        = v.name
      instance_id = v.instance_id
      managed     = v.managed
      owner       = v.owner
      size        = v.size
    }
  }
}

# ==============================================================================
# User Outputs
# ==============================================================================

output "users" {
  description = "Map of user keys to their details (passwords not exposed)."
  value = {
    for k, v in scaleway_rdb_user.this : k => {
      id       = v.id
      name     = v.name
      is_admin = var.users[k].is_admin
    }
  }
}

# ==============================================================================
# Privilege Outputs
# ==============================================================================

output "privileges" {
  description = "Map of privilege keys to their details."
  value = {
    for k, v in scaleway_rdb_privilege.this : k => {
      id            = v.id
      user_name     = v.user_name
      database_name = v.database_name
      permission    = v.permission
    }
  }
}

# ==============================================================================
# ACL Outputs
# ==============================================================================

output "acl_id" {
  description = "The ID of the ACL resource, null when there are no acl_rules."
  value       = try(scaleway_rdb_acl.this[0].id, null)
}

# ==============================================================================
# Backup Outputs
# ==============================================================================

output "manual_backups" {
  description = "Map of manual backup keys to their details."
  value = {
    for k, v in scaleway_rdb_database_backup.this : k => {
      id            = v.id
      name          = v.name
      database_name = v.database_name
      instance_id   = v.instance_id
      size          = v.size
      expires_at    = v.expires_at
      created_at    = v.created_at
      updated_at    = v.updated_at
    }
  }
}

# ==============================================================================
# Read Replica Outputs
# ==============================================================================

output "read_replicas" {
  description = "Map of read replica keys to their endpoint information (ip, port and hostname)."
  value = {
    for k, v in scaleway_rdb_read_replica.this : k => {
      id = v.id
      direct_access = try({
        ip       = v.direct_access[0].ip
        port     = v.direct_access[0].port
        hostname = v.direct_access[0].hostname
      }, null)
      private_network = try({
        ip       = v.private_network[0].ip
        port     = v.private_network[0].port
        hostname = v.private_network[0].hostname
      }, null)
    }
  }
}
