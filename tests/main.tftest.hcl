mock_provider "scaleway" {
  mock_resource "scaleway_rdb_instance" {
    defaults = {
      id = "fr-par/11111111-2222-3333-4444-555555555555"
    }
  }
}

variables {
  name      = "test-db"
  engine    = "PostgreSQL-16"
  node_type = "db-dev-s"
}

# ------------------------------------------------------------------------------
# Happy paths
# ------------------------------------------------------------------------------

run "minimal_without_project_uses_provider_default" {
  command = plan

  # The plan itself is the test: it used to fail in coalesce() with no project input.
  assert {
    condition     = scaleway_rdb_instance.this.encryption_at_rest && !scaleway_rdb_instance.this.backup_same_region
    error_message = "Defaults: encryption at rest on, backups stored in another region"
  }
}

run "project_id_direct" {
  command = plan

  variables {
    project_id = "99999999-2222-3333-4444-555555555555"
  }

  assert {
    condition     = scaleway_rdb_instance.this.project_id == "99999999-2222-3333-4444-555555555555"
    error_message = "project_id must be used as is"
  }
}

run "write_only_admin_password" {
  command = plan

  variables {
    admin_user          = { name = "admin", password_version = 3 }
    admin_user_password = "Abcdef1!xyz"
  }

  assert {
    condition     = scaleway_rdb_instance.this.user_name == "admin" && scaleway_rdb_instance.this.password_wo_version == 3 && scaleway_rdb_instance.this.password == null
    error_message = "The admin password must reach the instance through password_wo with its version and never as password"
  }
}

run "write_only_user_passwords" {
  command = plan

  variables {
    users = {
      app = { name = "app_service" }
      dba = { name = "dba", is_admin = true, password_version = 2 }
    }
    user_passwords = {
      app = "Abcdef1!xyz"
      dba = "Zyxwvu9#abc"
    }
  }

  assert {
    condition     = scaleway_rdb_user.this["app"].password_wo_version == 1 && scaleway_rdb_user.this["dba"].password_wo_version == 2
    error_message = "Each user must receive its password_version (default 1)"
  }

  assert {
    condition     = !scaleway_rdb_user.this["app"].is_admin && scaleway_rdb_user.this["dba"].is_admin && scaleway_rdb_user.this["app"].password == null
    error_message = "Users keep is_admin and never receive a plain password"
  }
}

run "backups_default_schedule" {
  command = plan

  assert {
    condition     = !scaleway_rdb_instance.this.disable_backup && scaleway_rdb_instance.this.backup_schedule_frequency == 24 && scaleway_rdb_instance.this.backup_schedule_retention == 14
    error_message = "Defaults: backups every 24 hours kept 14 days"
  }
}

run "volume_default_is_local_ssd" {
  command = plan

  assert {
    condition     = scaleway_rdb_instance.this.volume_type == "lssd"
    error_message = "The default volume type must be lssd"
  }
}

run "block_storage_volume_accepted" {
  command = plan

  variables {
    volume = { type = "sbs_5k", size_in_gb = 100 }
  }

  assert {
    condition     = scaleway_rdb_instance.this.volume_type == "sbs_5k" && scaleway_rdb_instance.this.volume_size_in_gb == 100
    error_message = "The volume object must reach the instance"
  }
}

run "tags_are_deduplicated" {
  command = plan

  variables {
    tags = ["environment=production", "environment=production", "team=platform"]
  }

  assert {
    condition     = length(scaleway_rdb_instance.this.tags) == 2 && contains(scaleway_rdb_instance.this.tags, "team=platform")
    error_message = "Duplicate tags must be removed"
  }
}

run "hybrid_endpoint_has_both" {
  command = plan

  variables {
    private_network = {
      pn_id       = "fr-par/11111111-2222-3333-4444-555555555555"
      enable_ipam = true
    }
    public_endpoint = true
  }

  assert {
    condition     = length(scaleway_rdb_instance.this.load_balancer) == 1 && length(scaleway_rdb_instance.this.private_network) == 1
    error_message = "public_endpoint = true must add a load_balancer block next to the private network"
  }
}

run "private_only_has_no_load_balancer" {
  command = plan

  variables {
    private_network = {
      pn_id       = "fr-par/11111111-2222-3333-4444-555555555555"
      enable_ipam = true
    }
  }

  assert {
    condition     = length(scaleway_rdb_instance.this.load_balancer) == 0 && length(scaleway_rdb_instance.this.private_network) == 1
    error_message = "A private instance has no load_balancer block by default"
  }
}

run "connection_falls_back_to_private_endpoint" {
  command = apply

  variables {
    private_network = {
      pn_id       = "fr-par/11111111-2222-3333-4444-555555555555"
      enable_ipam = true
    }
  }

  override_resource {
    target = scaleway_rdb_instance.this
    values = {
      id              = "fr-par/11111111-2222-3333-4444-555555555555"
      private_network = { ip = "10.0.0.5", port = 5432, hostname = "db.internal" }
    }
  }

  assert {
    condition     = output.instance_load_balancer == null && output.connection_host == "10.0.0.5" && output.connection_port == 5432
    error_message = "A private-only instance must connect through its private network endpoint"
  }
}

run "outputs_are_exposed" {
  command = apply

  variables {
    databases = { app = { name = "application" } }
    users     = { app = { name = "app_service" } }
    privileges = {
      app = { user_name = "app_service", database_name = "application", permission = "readwrite" }
    }
    user_passwords = { app = "Abcdef1!xyz" }
    acl_rules      = { office = { ip = "203.0.113.0/24", description = "Office" } }
    manual_backups = { b = { database_name = "application", name = "pre-migration" } }
    read_replicas  = { r = {} }
    private_network = {
      pn_id       = "fr-par/11111111-2222-3333-4444-555555555555"
      enable_ipam = true
    }
    public_endpoint = true
  }

  override_resource {
    target = scaleway_rdb_instance.this
    values = {
      id              = "fr-par/11111111-2222-3333-4444-555555555555"
      load_balancer   = { ip = "51.158.0.10", port = 5432, name = "lb", hostname = "db.example.com" }
      private_network = { ip = "10.0.0.5", port = 5432, hostname = "db.internal" }
    }
  }

  assert {
    condition = alltrue([
      output.project_id != null,
      output.instance_id != null,
      output.instance_region != null,
      output.instance_engine != null,
      nonsensitive(output.instance_certificate) != null,
      output.instance_load_balancer != null,
      output.connection_host == "51.158.0.10",
      output.connection_port == 5432,
      output.engine_type == "postgresql",
      output.engine_default_port == 5432,
      output.databases["app"].name == "application",
      output.users["app"].name == "app_service" && !output.users["app"].is_admin,
      output.privileges["app"].permission == "readwrite",
      output.acl_id != null,
      output.manual_backups["b"].name == "pre-migration",
    ])
    error_message = "The module outputs must be populated"
  }

  assert {
    condition     = output.instance_private_network.ip == "10.0.0.5" && output.read_replicas["r"].private_network == null
    error_message = "The instance exposes its private endpoint; a replica without private network has none"
  }

  assert {
    condition     = output.read_replicas["r"].direct_access.hostname != null
    error_message = "A replica must expose the hostname of its endpoint"
  }
}

run "backups_disabled_sends_no_region" {
  command = plan

  variables {
    backup = { enabled = false, same_region = true }
  }

  assert {
    condition     = scaleway_rdb_instance.this.disable_backup && !scaleway_rdb_instance.this.backup_same_region
    error_message = "backup_same_region must not be sent when backups are disabled"
  }

}

run "private_network_variants_accepted" {
  command = plan

  variables {
    private_network = {
      pn_id       = "fr-par/11111111-2222-3333-4444-555555555555"
      enable_ipam = true
    }
    read_replicas = {
      ipam   = { private_network = { pn_id = "fr-par/11111111-2222-3333-4444-555555555555", enable_ipam = true } }
      static = { private_network = { pn_id = "fr-par/11111111-2222-3333-4444-555555555555", ip_net = "192.168.1.10/24" } }
      direct = {}
    }
  }

  assert {
    condition     = length(scaleway_rdb_read_replica.this) == 3
    error_message = "Three replicas expected"
  }
}

# ------------------------------------------------------------------------------
# Preconditions
# ------------------------------------------------------------------------------

run "admin_user_without_password_rejected" {
  command = plan

  variables {
    admin_user = { name = "admin" }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "admin_password_without_user_rejected" {
  command = plan

  variables {
    admin_user_password = "Abcdef1!xyz"
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "block_storage_without_size_rejected" {
  command = plan

  variables {
    volume = { type = "sbs_5k" }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "block_storage_size_not_multiple_of_five_rejected" {
  command = plan

  variables {
    volume = { type = "sbs_15k", size_in_gb = 52 }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "public_endpoint_without_private_network_rejected" {
  command = plan

  variables {
    public_endpoint = true
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "user_without_password_rejected" {
  command = plan

  variables {
    users = { app = { name = "app_service" } }
  }

  expect_failures = [scaleway_rdb_user.this]
}

run "public_acl_rejected_without_flag" {
  command = plan

  variables {
    acl_rules = { world = { ip = "0.0.0.0/0", description = "world" } }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "public_acl_allowed_with_flag" {
  command = plan

  variables {
    allow_public_access = true
    acl_rules           = { world = { ip = "0.0.0.0/0", description = "world" } }
  }

  assert {
    condition     = length(scaleway_rdb_acl.this) == 1
    error_message = "The ACL must be planned when public access is allowed"
  }
}

# ------------------------------------------------------------------------------
# Validations
# ------------------------------------------------------------------------------

run "project_id_invalid_rejected" {
  command = plan

  variables {
    project_id = "1234"
  }

  expect_failures = [var.project_id]
}

run "admin_user_invalid_name_rejected" {
  command = plan

  variables {
    admin_user          = { name = "admin-user" }
    admin_user_password = "Abcdef1!xyz"
  }

  expect_failures = [var.admin_user]
}

run "admin_password_weak_rejected" {
  command = plan

  variables {
    admin_user          = { name = "admin" }
    admin_user_password = "Password!!"
  }

  expect_failures = [var.admin_user_password]
}

run "user_password_weak_rejected" {
  command = plan

  variables {
    users          = { app = { name = "app_service" } }
    user_passwords = { app = "Passw0rdOnly" }
  }

  expect_failures = [var.user_passwords]
}

run "user_passwords_unknown_key_rejected" {
  command = plan

  variables {
    user_passwords = { ghost = "Abcdef1!xyz" }
  }

  expect_failures = [var.user_passwords]
}

run "user_invalid_name_rejected" {
  command = plan

  variables {
    users          = { app = { name = "app-service" } }
    user_passwords = { app = "Abcdef1!xyz" }
  }

  expect_failures = [var.users]
}

run "volume_invalid_type_rejected" {
  command = plan

  variables {
    volume = { type = "bssd" }
  }

  expect_failures = [var.volume]
}

run "volume_size_out_of_range_rejected" {
  command = plan

  variables {
    volume = { size_in_gb = 4 }
  }

  expect_failures = [var.volume]
}

run "backup_frequency_out_of_range_rejected" {
  command = plan

  variables {
    backup = { frequency_hours = 169 }
  }

  expect_failures = [var.backup]
}

run "backup_frequency_zero_rejected" {
  command = plan

  variables {
    backup = { frequency_hours = 0 }
  }

  expect_failures = [var.backup]
}

run "backup_retention_out_of_range_rejected" {
  command = plan

  variables {
    backup = { retention_days = 366 }
  }

  expect_failures = [var.backup]
}

run "private_network_without_address_mode_rejected" {
  command = plan

  variables {
    private_network = { pn_id = "fr-par/11111111-2222-3333-4444-555555555555" }
  }

  expect_failures = [var.private_network]
}

run "private_network_with_both_address_modes_rejected" {
  command = plan

  variables {
    private_network = {
      pn_id       = "fr-par/11111111-2222-3333-4444-555555555555"
      ip_net      = "192.168.1.10/24"
      enable_ipam = true
    }
  }

  expect_failures = [var.private_network]
}

run "private_network_invalid_cidr_rejected" {
  command = plan

  variables {
    private_network = {
      pn_id  = "fr-par/11111111-2222-3333-4444-555555555555"
      ip_net = "192.168.1.10"
    }
  }

  expect_failures = [var.private_network]
}

run "replica_invalid_cidr_rejected" {
  command = plan

  variables {
    read_replicas = {
      r = { private_network = { pn_id = "fr-par/11111111-2222-3333-4444-555555555555", ip_net = "192.168.1.10" } }
    }
  }

  expect_failures = [var.read_replicas]
}

run "replica_without_address_mode_rejected" {
  command = plan

  variables {
    read_replicas = {
      r = { private_network = { pn_id = "fr-par/11111111-2222-3333-4444-555555555555" } }
    }
  }

  expect_failures = [var.read_replicas]
}

# ------------------------------------------------------------------------------
# Checks (warnings: the plan succeeds, expect_failures asserts they fire)
# ------------------------------------------------------------------------------

run "wide_ipv4_acl_warns" {
  command = plan

  variables {
    acl_rules = { half = { ip = "0.0.0.0/1", description = "half of the internet" } }
  }

  expect_failures = [check.acl_wide_ranges]
}

run "large_volume_with_manual_backup_warns" {
  command = plan

  variables {
    volume         = { type = "sbs_5k", size_in_gb = 600 }
    databases      = { app = { name = "application" } }
    manual_backups = { b = { database_name = "application", name = "pre-migration" } }
  }

  expect_failures = [check.manual_backup_volume_size]
}

# ------------------------------------------------------------------------------
# Clone from an existing instance
# ------------------------------------------------------------------------------

run "clone_public_plans_with_load_balancer" {
  command = plan

  variables {
    engine     = null
    clone_from = "fr-par/66666666-2222-3333-4444-555555555555"
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      engine             = "PostgreSQL-15"
      volume_type        = "lssd"
      volume_size_in_gb  = 0
      encryption_at_rest = true
      is_ha_cluster      = false
      init_settings      = {}
    }
  }

  assert {
    condition     = scaleway_rdb_instance.this.clone_from == "fr-par/66666666-2222-3333-4444-555555555555" && var.engine == null
    error_message = "A clone sets clone_from and no engine input"
  }

  assert {
    condition     = length(scaleway_rdb_instance.this.load_balancer) == 1 && length(scaleway_rdb_instance.this.private_network) == 0
    error_message = "A public clone keeps the load_balancer block"
  }

  assert {
    condition     = one(scaleway_rdb_instance.this.timeouts[*].update) == "60m"
    error_message = "The update timeout must be 60m"
  }
}

run "clone_private_has_no_load_balancer" {
  command = plan

  variables {
    engine     = null
    clone_from = "66666666-2222-3333-4444-555555555555"
    private_network = {
      pn_id       = "fr-par/11111111-2222-3333-4444-555555555555"
      enable_ipam = true
    }
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "lssd"
      encryption_at_rest = true
      is_ha_cluster      = false
      init_settings      = {}
    }
  }

  assert {
    condition     = length(scaleway_rdb_instance.this.load_balancer) == 0 && length(scaleway_rdb_instance.this.private_network) == 1
    error_message = "A private clone has the private network and no load_balancer block"
  }
}

run "clone_private_with_public_endpoint_has_both" {
  command = plan

  variables {
    engine     = null
    clone_from = "66666666-2222-3333-4444-555555555555"
    private_network = {
      pn_id       = "fr-par/11111111-2222-3333-4444-555555555555"
      enable_ipam = true
    }
    public_endpoint = true
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "lssd"
      encryption_at_rest = true
      is_ha_cluster      = false
      init_settings      = {}
    }
  }

  assert {
    condition     = length(scaleway_rdb_instance.this.load_balancer) == 1 && length(scaleway_rdb_instance.this.private_network) == 1
    error_message = "A private clone with public_endpoint = true keeps both endpoints"
  }
}

run "not_a_clone_has_no_load_balancer" {
  command = plan

  assert {
    condition     = length(scaleway_rdb_instance.this.load_balancer) == 0 && scaleway_rdb_instance.this.clone_from == null
    error_message = "A regular instance has no load_balancer block and no clone_from"
  }

  assert {
    condition     = one(scaleway_rdb_instance.this.timeouts[*].update) == "60m"
    error_message = "The update timeout must be 60m"
  }
}

run "clone_ha_source_cloned_as_ha" {
  command = plan

  variables {
    engine        = null
    clone_from    = "66666666-2222-3333-4444-555555555555"
    is_ha_cluster = true
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "lssd"
      encryption_at_rest = true
      is_ha_cluster      = true
      init_settings      = {}
    }
  }

  assert {
    condition     = scaleway_rdb_instance.this.is_ha_cluster
    error_message = "An HA source can be cloned with is_ha_cluster = true"
  }
}

run "clone_engine_type_follows_the_instance" {
  command = apply

  variables {
    engine     = null
    clone_from = "66666666-2222-3333-4444-555555555555"
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "lssd"
      encryption_at_rest = true
      is_ha_cluster      = false
      init_settings      = {}
    }
  }

  override_resource {
    target = scaleway_rdb_instance.this
    values = {
      id     = "fr-par/11111111-2222-3333-4444-555555555555"
      engine = "MySQL-8"
    }
  }

  assert {
    condition     = output.engine_type == "mysql" && output.engine_default_port == 3306
    error_message = "engine_type and engine_default_port must follow the engine of the clone"
  }
}

run "clone_invalid_source_rejected" {
  command = plan

  variables {
    engine     = null
    clone_from = "not-an-id"
  }

  expect_failures = [var.clone_from]
}

run "engine_unsupported_still_rejected" {
  command = plan

  variables {
    engine = "PostgreSQL-10"
  }

  expect_failures = [var.engine]
}

run "neither_engine_nor_clone_rejected" {
  command = plan

  variables {
    engine = null
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "both_engine_and_clone_rejected" {
  command = plan

  variables {
    clone_from = "66666666-2222-3333-4444-555555555555"
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "lssd"
      encryption_at_rest = true
      is_ha_cluster      = false
      init_settings      = {}
    }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "clone_with_admin_user_rejected" {
  command = plan

  variables {
    engine              = null
    clone_from          = "66666666-2222-3333-4444-555555555555"
    admin_user          = { name = "admin" }
    admin_user_password = "Abcdef1!xyz"
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "lssd"
      encryption_at_rest = true
      is_ha_cluster      = false
      init_settings      = {}
    }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "clone_block_storage_source_with_default_volume_rejected" {
  command = plan

  variables {
    engine     = null
    clone_from = "66666666-2222-3333-4444-555555555555"
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "sbs_5k"
      volume_size_in_gb  = 50
      encryption_at_rest = true
      is_ha_cluster      = false
      init_settings      = {}
    }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "clone_unencrypted_source_with_default_encryption_rejected" {
  command = plan

  variables {
    engine     = null
    clone_from = "66666666-2222-3333-4444-555555555555"
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "lssd"
      encryption_at_rest = false
      is_ha_cluster      = false
      init_settings      = {}
    }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

run "clone_ha_source_with_default_ha_rejected" {
  command = plan

  variables {
    engine     = null
    clone_from = "66666666-2222-3333-4444-555555555555"
  }

  override_data {
    target = data.scaleway_rdb_instance.source
    values = {
      volume_type        = "lssd"
      encryption_at_rest = true
      is_ha_cluster      = true
      init_settings      = {}
    }
  }

  expect_failures = [scaleway_rdb_instance.this]
}

# ------------------------------------------------------------------------------
# Manual backup expiry
# ------------------------------------------------------------------------------

run "manual_backup_with_expiry" {
  command = apply

  variables {
    databases      = { app = { name = "application" } }
    manual_backups = { b = { database_name = "application", name = "pre-migration", expires_at = "2027-01-31T00:00:00Z" } }
  }

  override_resource {
    target = scaleway_rdb_instance.this
    values = {
      id = "fr-par/11111111-2222-3333-4444-555555555555"
    }
  }

  assert {
    condition     = scaleway_rdb_database_backup.this["b"].expires_at == "2027-01-31T00:00:00Z"
    error_message = "The backup must carry the expiry"
  }

  assert {
    condition     = output.manual_backups["b"].expires_at == "2027-01-31T00:00:00Z"
    error_message = "The manual_backups output must expose expires_at"
  }
}

run "manual_backup_offset_expiry_rejected" {
  command = plan

  variables {
    manual_backups = { b = { database_name = "application", name = "pre-migration", expires_at = "2027-01-31T01:00:00+01:00" } }
  }

  expect_failures = [var.manual_backups]
}

run "manual_backup_invalid_expiry_rejected" {
  command = plan

  variables {
    manual_backups = { b = { database_name = "application", name = "pre-migration", expires_at = "next week" } }
  }

  expect_failures = [var.manual_backups]
}
