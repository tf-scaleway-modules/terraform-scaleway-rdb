# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              VERSION CONSTRAINTS                             ║
# ║                                                                              ║
# ║  Terraform/OpenTofu and provider version requirements.                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.10.7" # OpenTofu 1.10.7 or Terraform 1.10.7+

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.64"
    }
  }
}
