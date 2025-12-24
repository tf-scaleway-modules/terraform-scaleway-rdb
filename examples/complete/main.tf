# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║             COMPLETE EXAMPLE - SCALEWAY Relational Database MODULE           ║
# ║                                                                              ║
# ║  Advanced usage demonstrating all
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Provider Configuration
# ==============================================================================

provider "scaleway" {
  region = "fr-par"
}

# ==============================================================================
# Variables
# ==============================================================================

variable "organization_id" {
  description = "Your Scaleway Organization ID"
  type        = string
}

variable "project_name" {
  description = "Your Scaleway Project name"
  type        = string
}
