# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              MODULE OUTPUTS                                  ║
# ║                                                                              ║
# ║  Outputs for RDB instance, databases, users, and related resources.         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project Output
# ==============================================================================

output "project_id" {
  description = "The ID of the Scaleway project (resolved from project_name or provided directly)."
  value       = local.project_id
}

# ==============================================================================
# Instance Outputs
# ==============================================================================

output "instance_id" {
  description = "The ID of the RDB instance."
  value       = scaleway_rdb_instance.this.id
}

output "instance_name" {
  description = "The name of the RDB instance."
  value       = scaleway_rdb_instance.this.name
}

output "instance_endpoint_ip" {
  description = "The IP address of the RDB instance endpoint."
  value       = scaleway_rdb_instance.this.endpoint_ip
}

output "instance_endpoint_port" {
  description = "The port of the RDB instance endpoint."
  value       = scaleway_rdb_instance.this.endpoint_port
}

output "instance_load_balancer" {
  description = "Load balancer endpoint information for the RDB instance."
  value = try({
    ip       = scaleway_rdb_instance.this.load_balancer[0].ip
    port     = scaleway_rdb_instance.this.load_balancer[0].port
    name     = scaleway_rdb_instance.this.load_balancer[0].name
    hostname = scaleway_rdb_instance.this.load_balancer[0].hostname
  }, null)
}

output "instance_private_network" {
  description = "Private network endpoint information for the RDB instance."
  value = try({
    ip       = scaleway_rdb_instance.this.private_network[0].ip
    port     = scaleway_rdb_instance.this.private_network[0].port
    hostname = scaleway_rdb_instance.this.private_network[0].hostname
  }, null)
}

output "instance_certificate" {
  description = "The PEM-encoded TLS certificate for secure connections."
  value       = scaleway_rdb_instance.this.certificate
  sensitive   = true
}

output "instance_engine" {
  description = "The database engine and version."
  value       = scaleway_rdb_instance.this.engine
}

output "instance_is_ha_cluster" {
  description = "Whether the instance is a high availability cluster."
  value       = scaleway_rdb_instance.this.is_ha_cluster
}

output "instance_node_type" {
  description = "The node type of the RDB instance."
  value       = scaleway_rdb_instance.this.node_type
}

output "instance_region" {
  description = "The region where the RDB instance is deployed."
  value       = scaleway_rdb_instance.this.region
}

# ==============================================================================
# Admin Password Output
# ==============================================================================

output "admin_password" {
  description = <<-EOT
    The admin user password.

    Returns the provided password if admin_user_password was set,
    or the auto-generated password from the instance if not.

    WARNING: This is sensitive data - handle with care.
  EOT
  value       = var.admin_user_password != null ? var.admin_user_password : try(scaleway_rdb_instance.this.password, null)
  sensitive   = true
}

# ==============================================================================
# Connection Strings
# ==============================================================================

output "connection_string" {
  description = <<-EOT
    Database connection string.

    For PostgreSQL: postgres://user:password@host:port/database?sslmode=require
    For MySQL: mysql://user:password@host:port/database

    Note: This output requires admin_user_name to be set.
  EOT
  value = var.admin_user_name != null ? (
    local.is_postgresql ? format(
      "postgres://%s:%s@%s:%d/%s?sslmode=require",
      var.admin_user_name,
      var.admin_user_password,
      try(scaleway_rdb_instance.this.load_balancer[0].ip, scaleway_rdb_instance.this.endpoint_ip),
      try(scaleway_rdb_instance.this.load_balancer[0].port, scaleway_rdb_instance.this.endpoint_port),
      "postgres"
      ) : format(
      "mysql://%s:%s@%s:%d",
      var.admin_user_name,
      var.admin_user_password,
      try(scaleway_rdb_instance.this.load_balancer[0].ip, scaleway_rdb_instance.this.endpoint_ip),
      try(scaleway_rdb_instance.this.load_balancer[0].port, scaleway_rdb_instance.this.endpoint_port)
    )
  ) : null
  sensitive = true
}

output "connection_host" {
  description = "The hostname or IP address for database connections."
  value       = try(scaleway_rdb_instance.this.load_balancer[0].ip, scaleway_rdb_instance.this.endpoint_ip)
}

output "connection_port" {
  description = "The port for database connections."
  value       = try(scaleway_rdb_instance.this.load_balancer[0].port, scaleway_rdb_instance.this.endpoint_port)
}

# ==============================================================================
# Database Outputs
# ==============================================================================

output "database_ids" {
  description = "Map of database keys to their IDs."
  value       = local.database_ids
}

output "databases" {
  description = "Map of database keys to their full details."
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

output "user_names" {
  description = "Map of user keys to their usernames (passwords not exposed)."
  value = {
    for k, v in scaleway_rdb_user.this : k => v.name
  }
}

output "users" {
  description = "Map of user keys to their details (passwords not exposed)."
  value       = local.user_info
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
  description = "The ID of the ACL resource."
  value       = try(scaleway_rdb_acl.this[0].id, null)
}

output "acl_rules" {
  description = "The ACL rules applied to the instance."
  value       = try(scaleway_rdb_acl.this[0].acl_rules, [])
}

# ==============================================================================
# Read Replica Outputs
# ==============================================================================

output "read_replicas" {
  description = "Map of read replica keys to their endpoint information."
  value       = local.read_replica_endpoints
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
      created_at    = v.created_at
      updated_at    = v.updated_at
    }
  }
}

# ==============================================================================
# Security Outputs
# ==============================================================================

output "encryption_at_rest_enabled" {
  description = "Whether encryption at rest is enabled."
  value       = var.encryption_at_rest
}

output "backup_enabled" {
  description = "Whether automated backups are enabled."
  value       = var.backup_enabled
}
