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
}
