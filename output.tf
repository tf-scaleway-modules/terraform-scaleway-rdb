output "pg_conn_str" {
  description = "PostgreSQL connection string"
  value = format(
    "postgres://%s:%s@%s:%d/%s?sslmode=disable",
    var.username,
    var.password,
    scaleway_rdb_instance.main.endpoint[0].ip,
    scaleway_rdb_instance.main.endpoint[0].port,
    var.database_name
  )
  sensitive = true
}
