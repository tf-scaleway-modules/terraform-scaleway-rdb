# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           RDB INSTANCE RESOURCE                              ║
# ║                                                                              ║
# ║  Primary Scaleway Relational Database instance configuration.               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "scaleway_rdb_instance" "this" {
  name       = var.name
  engine     = var.engine
  node_type  = var.node_type
  region     = var.region
  project_id = local.project_id

  # High Availability
  is_ha_cluster = var.is_ha_cluster

  # Admin user (optional - created with instance)
  user_name = var.admin_user_name
  password  = var.admin_user_password

  # Storage configuration
  volume_type       = var.volume_type
  volume_size_in_gb = var.volume_size_in_gb

  # Security - encryption at rest
  encryption_at_rest = var.encryption_at_rest

  # Backup configuration
  disable_backup            = !var.backup_enabled
  backup_schedule_frequency = var.backup_enabled ? var.backup_schedule_frequency : null
  backup_schedule_retention = var.backup_enabled ? var.backup_schedule_retention : null
  backup_same_region        = var.backup_same_region

  # Engine settings
  settings      = var.settings
  init_settings = var.init_settings

  # Private network configuration
  dynamic "private_network" {
    for_each = var.private_network != null ? [var.private_network] : []
    content {
      pn_id       = private_network.value.pn_id
      ip_net      = private_network.value.ip_net
      enable_ipam = private_network.value.enable_ipam
    }
  }

  # Logs policy configuration
  dynamic "logs_policy" {
    for_each = var.logs_policy != null ? [var.logs_policy] : []
    content {
      max_age_retention    = logs_policy.value.max_age_retention
      total_disk_retention = logs_policy.value.total_disk_retention
    }
  }

  # Tags - convert map to Scaleway format
  tags = local.tags_list

  # Lifecycle rules
  lifecycle {
    # Prevent accidental destruction in production
    prevent_destroy = false

    # Validate project configuration
    precondition {
      condition = (
        var.project_id != null ||
        (var.organization_id != null && var.project_name != null) ||
        (var.project_id == null && var.organization_id == null && var.project_name == null)
      )
      error_message = "Either provide project_id directly, or both organization_id and project_name for lookup, or none to use provider default."
    }

    # Validate volume size for block storage
    precondition {
      condition = var.volume_type == "lssd" || (
        var.volume_size_in_gb != null && var.volume_size_in_gb % 5 == 0
      )
      error_message = "volume_size_in_gb must be set and be a multiple of 5 when using bssd, sbs_5k, or sbs_15k volume_type."
    }

    # Validate admin user configuration
    precondition {
      condition = (var.admin_user_name == null && var.admin_user_password == null) || (
        var.admin_user_name != null && var.admin_user_password != null
      )
      error_message = "Both admin_user_name and admin_user_password must be set together, or neither."
    }

    # Validate ACL security - prevent public access unless explicitly allowed
    precondition {
      condition = var.allow_public_access || !anytrue([
        for rule in var.acl_rules : rule.ip == "0.0.0.0/0"
      ])
      error_message = "ACL rule 0.0.0.0/0 (public access) is not allowed unless allow_public_access is set to true."
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           DATABASE RESOURCES                                 ║
# ║                                                                              ║
# ║  Creates databases within the RDB instance.                                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "scaleway_rdb_database" "this" {
  for_each = var.databases

  instance_id = scaleway_rdb_instance.this.id
  name        = each.value.name
  region      = var.region
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              USER RESOURCES                                  ║
# ║                                                                              ║
# ║  Creates database users within the RDB instance.                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "scaleway_rdb_user" "this" {
  for_each = var.users

  instance_id = scaleway_rdb_instance.this.id
  name        = each.value.name
  password    = each.value.password
  is_admin    = each.value.is_admin
  region      = var.region
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           PRIVILEGE RESOURCES                                ║
# ║                                                                              ║
# ║  Grants database privileges to users.                                        ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "scaleway_rdb_privilege" "this" {
  for_each = var.privileges

  instance_id   = scaleway_rdb_instance.this.id
  user_name     = each.value.user_name
  database_name = each.value.database_name
  permission    = each.value.permission
  region        = var.region

  # Ensure databases and users are created before privileges
  depends_on = [
    scaleway_rdb_database.this,
    scaleway_rdb_user.this
  ]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              ACL RESOURCE                                    ║
# ║                                                                              ║
# ║  Controls network access to the RDB instance.                                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "scaleway_rdb_acl" "this" {
  count = length(var.acl_rules) > 0 ? 1 : 0

  instance_id = scaleway_rdb_instance.this.id
  region      = var.region

  dynamic "acl_rules" {
    for_each = var.acl_rules
    content {
      ip          = acl_rules.value.ip
      description = acl_rules.value.description
    }
  }
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         MANUAL BACKUP RESOURCES                              ║
# ║                                                                              ║
# ║  Creates manual database backups (independent of automatic backups).         ║
# ║                                                                              ║
# ║  Note: Automatic backups are configured on the RDB instance resource.        ║
# ║  Manual backups are point-in-time exports of specific databases.             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "scaleway_rdb_database_backup" "this" {
  for_each = var.manual_backups

  instance_id   = scaleway_rdb_instance.this.id
  database_name = each.value.database_name
  name          = each.value.name
  region        = var.region

  # Ensure databases exist before creating backups
  depends_on = [scaleway_rdb_database.this]
}

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                          READ REPLICA RESOURCES                              ║
# ║                                                                              ║
# ║  Creates read replicas for read scaling and high availability.              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "scaleway_rdb_read_replica" "this" {
  for_each = var.read_replicas

  instance_id = scaleway_rdb_instance.this.id
  region      = each.value.region
  same_zone   = each.value.same_zone

  # Private network configuration for replica
  dynamic "private_network" {
    for_each = each.value.private_network != null ? [each.value.private_network] : []
    content {
      private_network_id = private_network.value.pn_id
      service_ip         = private_network.value.ip_net
      enable_ipam        = private_network.value.enable_ipam
    }
  }

  # Direct access endpoint (when not using private network)
  dynamic "direct_access" {
    for_each = each.value.private_network == null ? [1] : []
    content {}
  }
}
