# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           RDB INSTANCE RESOURCE                              ║
# ║                                                                              ║
# ║  Primary Scaleway Relational Database instance configuration.               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

resource "scaleway_rdb_instance" "this" {
  name       = var.name
  engine     = var.engine
  node_type  = var.node_type
  clone_from = var.clone_from
  region     = var.region
  project_id = local.project_id

  # High Availability
  is_ha_cluster = var.is_ha_cluster

  # Admin user (optional - created with instance)
  user_name           = var.admin_user_name
  password            = var.admin_user_password
  password_wo         = var.admin_user_password_wo
  password_wo_version = var.admin_user_password_wo_version

  # Storage configuration
  volume_type       = var.volume_type
  volume_size_in_gb = var.volume_size_in_gb

  # Security - encryption at rest
  encryption_at_rest = var.encryption_at_rest

  # Backup configuration
  disable_backup            = !var.backup_enabled
  backup_schedule_frequency = var.backup_enabled ? var.backup_schedule_frequency : null
  backup_schedule_retention = var.backup_enabled ? var.backup_schedule_retention : null
  backup_same_region        = var.backup_enabled ? var.backup_same_region : null

  # Engine settings
  settings      = var.settings
  init_settings = var.init_settings

  # Public endpoint of a clone: without this block the provider deletes the one
  # created by the clone, leaving no endpoint when private_network is not set
  dynamic "load_balancer" {
    for_each = var.clone_from != null && var.private_network == null ? [1] : []
    content {}
  }

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
    # NOTE: Set to true manually for production - cannot be variable due to Terraform limitation
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
      error_message = "volume_size_in_gb must be set and be a multiple of 5 when using sbs_5k or sbs_15k volume_type."
    }

    # Validate admin user configuration
    precondition {
      condition = var.admin_user_name == null ? (
        var.admin_user_password == null && var.admin_user_password_wo == null
      ) : (var.admin_user_password == null) != (var.admin_user_password_wo == null)
      error_message = "admin_user_name must be set together with exactly one of admin_user_password or admin_user_password_wo, or none of them."
    }

    # Validate engine source
    precondition {
      condition     = (var.engine == null) != (var.clone_from == null)
      error_message = "Set exactly one of engine or clone_from."
    }

    # A clone keeps the users of its source
    precondition {
      condition = var.clone_from == null || (
        var.admin_user_name == null && var.admin_user_password == null && var.admin_user_password_wo == null
      )
      error_message = "admin_user_name and the admin password cannot be set with clone_from: the clone keeps the users of its source."
    }

    # The provider does not apply these at clone time: they must equal the source
    precondition {
      condition = var.clone_from == null || (
        var.volume_type == one(data.scaleway_rdb_instance.source[*].volume_type) &&
        (var.volume_type == "lssd" || var.volume_size_in_gb == one(data.scaleway_rdb_instance.source[*].volume_size_in_gb)) &&
        var.encryption_at_rest == one(data.scaleway_rdb_instance.source[*].encryption_at_rest) &&
        var.init_settings == one(data.scaleway_rdb_instance.source[*].init_settings)
      )
      error_message = "With clone_from, volume_type, volume_size_in_gb (block storage), encryption_at_rest and init_settings must match the source instance."
    }

    # The default is_ha_cluster = false would ask the provider to switch HA off on the clone
    precondition {
      condition     = var.clone_from == null || var.is_ha_cluster || !one(data.scaleway_rdb_instance.source[*].is_ha_cluster)
      error_message = "clone_from cannot turn off high availability: set is_ha_cluster = true to clone a high-availability source."
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
    update = "60m"
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

  instance_id         = scaleway_rdb_instance.this.id
  name                = each.value.name
  password            = each.value.password
  password_wo         = each.value.password_wo
  password_wo_version = each.value.password_wo_version
  is_admin            = each.value.is_admin
  region              = var.region
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
  expires_at    = each.value.expires_at
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
