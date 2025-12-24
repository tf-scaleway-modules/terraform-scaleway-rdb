# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              MODULE OUTPUTS                                  ║
# ║                                                                              ║
# ║  Outputs for domain registration, DNS zones, and records.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project Output
# ==============================================================================

output "project_id" {
  description = "The ID of the Scaleway project (resolved from project_name or provided directly)."
  value       = local.project_id
}

output "pg_conn_str" {
  description = "PostgreSQL connection string"
  value = format(
    "postgres://%s:%s@%s:%d/%s?sslmode=disable",
    var.username,
    var.password,
    scaleway_rdb_instance.main.load_balancer[0].ip,
    scaleway_rdb_instance.main.load_balancer[0].port,
    var.database_name
  )
  sensitive = true
}
