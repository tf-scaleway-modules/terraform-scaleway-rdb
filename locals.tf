# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              LOCAL VALUES                                    ║
# ║                                                                              ║
# ║  Engine helpers used by the outputs.                                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

locals {
  # Engine of the instance: the input, or the engine of the source for a clone
  engine = var.engine != null ? var.engine : scaleway_rdb_instance.this.engine

  is_postgresql = can(regex("^PostgreSQL-", local.engine))
}
