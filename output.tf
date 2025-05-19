output "pg_conn_str" {
  description = "PostgreSQL connection string"
  value = format(
    "postgres://%s:%s@%s:%d/%s?sslmode=disable",
    var.username,
    var.password,
    scaleway_rdb_instance.main.load_balancer[0].ip,
    scaleway_rdb_instance.main.load_balancer[0].port,
    scaleway_rdb_instance.main.load_balancer[0].hostname,
    var.database_name
  )
  sensitive = true
}
