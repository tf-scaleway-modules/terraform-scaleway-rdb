variable "name" {
  type        = string
  description = "The name of the Redis cluster"
}

variable "tags" {
  type = map(any)
}

variable "region" {
  type = string
}

variable "username" {
  type        = string
}

variable "node_type" {
  type = string
}

variable "postgres_version" {
  type = string
}

variable "cluster_mode" {
  type = string
}

variable "backups" {
  type = object({
    enabled        = bool
    retention_days = optional(number)
    frequency_days = optional(number)
  })
}

variable "database_name" {
  type        = string
  description = "The name of database"
}