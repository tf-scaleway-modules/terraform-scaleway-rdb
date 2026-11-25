## MODIFIED Requirements

### Requirement: Supported tool and provider versions
The module SHALL declare `required_version = ">= 1.11.0"` and the provider `scaleway/scaleway` with version constraint `~> 2.89` in `versions.tf`, because `clone_from` exists from provider 2.89.0. Both OpenTofu and Terraform SHALL accept the module at that floor; the single `required_version` constraint serves both and no OpenTofu-only construct is used.

#### Scenario: Older OpenTofu or Terraform
- **WHEN** the module is initialised with OpenTofu or Terraform older than 1.11.0
- **THEN** initialisation fails on the `required_version` constraint

#### Scenario: Provider constraint
- **WHEN** the module is initialised
- **THEN** the `scaleway/scaleway` provider is selected within `~> 2.89`

#### Scenario: Older provider locked by the caller
- **WHEN** the caller's lock file pins `scaleway/scaleway` 2.86.0
- **THEN** `init` fails until the caller runs `init -upgrade`

#### Scenario: Terraform consumer
- **WHEN** the module and each example under `examples/` are initialised with `terraform init -backend=false` and checked with `terraform validate` on Terraform 1.11.0 or later
- **THEN** validation succeeds, exactly as with OpenTofu
