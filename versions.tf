# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              VERSION CONSTRAINTS                             ║
# ║                                                                              ║
# ║  Terraform/OpenTofu and provider version requirements.                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.11.0" # OpenTofu/Terraform 1.11+ (write-only arguments)

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.89"
    }
  }
}
