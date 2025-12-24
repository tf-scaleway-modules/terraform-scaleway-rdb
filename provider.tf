terraform {
  required_version = ">= 0.14"
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.16"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}