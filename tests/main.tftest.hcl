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
