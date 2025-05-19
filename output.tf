output "pg_conn_str" {
  description = "PostgreSQL connection string"
  value = format(
    "postgres://%s:%s@%s:%d/%s?sslmode=disable",
    var.username,
    var.password,
    scaleway_rdb_instance.main.load_balancer.ip,
    scaleway_rdb_instance.main.load_balancer.port,
    scaleway_rdb_instance.main.load_balancer.hostname,
    scaleway_rdb_instance.main.load_balancer.name,
    var.database_name
  )
  sensitive = true
}
