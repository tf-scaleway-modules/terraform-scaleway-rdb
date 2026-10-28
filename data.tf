# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              DATA SOURCES                                    ║
# ║                                                                              ║
# ║  External data lookups for existing Scaleway resources.                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project Data Source
# ------------------------------------------------------------------------------
# Looks up the Scaleway project by name to get the project ID.
# This allows users to reference projects by name instead of ID.
# Only created when organization_id and project_name are provided.
# ==============================================================================

data "scaleway_account_project" "this" {
  count = var.organization_id != null && var.project_name != null ? 1 : 0

  name            = var.project_name
  organization_id = var.organization_id
}

# ==============================================================================
# Clone Source Data Source
# ------------------------------------------------------------------------------
# Reads the instance given in clone_from once, to check that the inputs the
# provider does not apply at clone time equal the source values.
# Only read when clone_from is set.
# ==============================================================================

data "scaleway_rdb_instance" "source" {
  count = var.clone_from != null ? 1 : 0

  instance_id = var.clone_from
  region      = var.region
}
