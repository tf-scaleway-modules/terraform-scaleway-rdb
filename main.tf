resource "scaleway_rdb_instance" "main" {
  name                      = var.name
  tags                      = [for k, v in var.tags : "${k}::${v}"]
  node_type                 = var.node_type
  engine                    = var.postgres_version
  is_ha_cluster             = var.cluster_mode == "highly-available" ? true : false
  user_name                 = var.username
  password                  = random_password.root_user_password.result
  region                    = var.region
  disable_backup            = var.backups.enabled ? false : true
  backup_schedule_frequency = var.backups.enabled ? var.backups.frequency_days : null
  backup_schedule_retention = var.backups.enabled ? var.backups.retention_days : null
}

resource "scaleway_rdb_database" "main" {
  instance_id = scaleway_rdb_instance.main.id
  name        = var.database_name
}