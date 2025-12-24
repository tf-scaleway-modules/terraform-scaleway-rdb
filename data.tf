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
