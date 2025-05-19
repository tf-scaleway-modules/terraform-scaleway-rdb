output "pg_conn_str" {
  description = "PostgreSQL connection string"
  value = format(
    "postgres://%s:%s@%s:%d/%s?sslmode=disable",
    var.username,
    var.password,
    scaleway_rdb_instance.main.private_network[0].hostname,
    scaleway_rdb_instance.main.private_network[0].port,
    var.database_name
  )
  sensitive = true
}
