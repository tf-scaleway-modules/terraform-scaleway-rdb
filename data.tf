# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              DATA SOURCES                                    ║
# ║                                                                              ║
# ║  External data lookups for existing Scaleway resources.                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

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
