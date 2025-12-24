# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              LOCAL VALUES                                    ║
# ║                                                                              ║
# ║  Computed values and transformations used throughout the module.             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

locals {
  # ==============================================================================
  # Project ID Resolution
  # ------------------------------------------------------------------------------
  # Priority: project_id > data source lookup > null (provider default)
  # ==============================================================================

  project_id = coalesce(
    var.project_id,
    try(data.scaleway_account_project.this[0].id, null)
  )

  # ==============================================================================
  # Tags Transformation
  # ------------------------------------------------------------------------------
  # Convert map of tags to Scaleway's list format: ["key=value", ...]
  # ==============================================================================

  tags_list = [for k, v in var.tags : "${k}=${v}"]

  # ==============================================================================
  # Connection String Helpers
  # ------------------------------------------------------------------------------
  # Build connection strings for supported engines
  # ==============================================================================

  # Determine if engine is PostgreSQL
  is_postgresql = can(regex("^PostgreSQL-", var.engine))

  # Determine if engine is MySQL
  is_mysql = can(regex("^MySQL-", var.engine))

  # Default port based on engine
  default_port = local.is_postgresql ? 5432 : 3306

  # ==============================================================================
  # Database and User Maps
  # ------------------------------------------------------------------------------
  # Create maps for easy lookup of created resources
  # ==============================================================================

  # Map of database names to their IDs
  database_ids = {
    for k, v in scaleway_rdb_database.this : k => v.id
  }

  # Map of user names to their info (excluding passwords)
  user_info = {
    for k, v in scaleway_rdb_user.this : k => {
      id       = v.id
      name     = v.name
      is_admin = var.users[k].is_admin
    }
  }

  # ==============================================================================
  # Read Replica Endpoints
  # ------------------------------------------------------------------------------
  # Collect endpoints for all read replicas
  # ==============================================================================

  read_replica_endpoints = {
    for k, v in scaleway_rdb_read_replica.this : k => {
      id = v.id
      direct_access = try({
        ip   = v.direct_access[0].ip
        port = v.direct_access[0].port
      }, null)
      private_network = try({
        ip   = v.private_network[0].ip
        port = v.private_network[0].port
      }, null)
    }
  }
}
