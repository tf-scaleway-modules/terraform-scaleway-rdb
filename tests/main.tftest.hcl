mock_provider "scaleway" {
  mock_resource "scaleway_rdb_instance" {
    defaults = {
      id = "fr-par/11111111-2222-3333-4444-555555555555"
    }
  }
}

override_data {
  target = data.scaleway_account_project.this
  values = {
    id = "11111111-2222-3333-4444-555555555555"
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

run "project_lookup_by_name" {
  command = plan

  variables {
    organization_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    project_name    = "my-project"
  }

  assert {
    condition     = scaleway_rdb_instance.this.project_id == "11111111-2222-3333-4444-555555555555"
    error_message = "The project must be resolved by name"
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
    admin_user_name                = "admin"
    admin_user_password_wo         = "Abcdef1!xyz"
    admin_user_password_wo_version = 1
  }

  assert {
    condition     = output.admin_password == null && output.connection_string == null
    error_message = "A write-only admin password must not be exposed by the outputs"
  }
}

run "backups_disabled_sends_no_region" {
  command = plan

  variables {
    backup_enabled     = false
    backup_same_region = true
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

run "organization_without_project_name_rejected" {
  command = plan

  variables {
    organization_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  }

  expect_failures = [scaleway_rdb_instance.this]
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
    volume_type       = "sbs_5k"
    volume_size_in_gb = 600
    databases         = { app = { name = "application" } }
    manual_backups    = { b = { database_name = "application", name = "pre-migration" } }
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
    engine                 = null
    clone_from             = "66666666-2222-3333-4444-555555555555"
    admin_user_name        = "admin"
    admin_user_password_wo = "Abcdef1!xyz"
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
