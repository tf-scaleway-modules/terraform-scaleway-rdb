# Scaleway Relational Database Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Scaleway Provider][scaleway-badge]][scaleway-url]

A **production-ready** Terraform/OpenTofu module for managing Scaleway Relational Database .

## Features

## Quick Start

### Prerequisites

### Basic Usage




## Examples

- [Minimal](./examples/minimal/) - Basic A, CNAME, and MX records
- [Complete](./examples/complete/) - All DNS features including dynamic DNS

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.7 |
| <a name="requirement_scaleway"></a> [scaleway](#requirement\_scaleway) | ~> 2.64 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_scaleway"></a> [scaleway](#provider\_scaleway) | ~> 2.64 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [scaleway_rdb_database.main](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_database) | resource |
| [scaleway_rdb_instance.main](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/rdb_instance) | resource |
| [scaleway_account_project.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/data-sources/account_project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backups"></a> [backups](#input\_backups) | n/a | <pre>object({<br/>    enabled        = bool<br/>    retention_days = optional(number)<br/>    frequency_days = optional(number)<br/>  })</pre> | n/a | yes |
| <a name="input_cluster_mode"></a> [cluster\_mode](#input\_cluster\_mode) | n/a | `string` | n/a | yes |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | The name of database | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The name of the Redis cluster | `string` | n/a | yes |
| <a name="input_node_type"></a> [node\_type](#input\_node\_type) | n/a | `string` | n/a | yes |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | Scaleway Organization ID.<br/><br/>Required when using project\_name to look up the project.<br/>The organization is the top-level entity in Scaleway's hierarchy.<br/>Find this in the Scaleway Console under Organization Settings.<br/><br/>Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) | `string` | `null` | no |
| <a name="input_password"></a> [password](#input\_password) | n/a | `string` | n/a | yes |
| <a name="input_postgres_engine"></a> [postgres\_engine](#input\_postgres\_engine) | n/a | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Scaleway Project ID where the DNS zone will be created.<br/><br/>Either provide project\_id directly, or use organization\_id + project\_name<br/>to look up the project. If neither is provided, uses the default project<br/>from provider configuration.<br/><br/>Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) | `string` | `null` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Scaleway Project name where resources will be created.<br/><br/>Use this with organization\_id to look up the project by name.<br/>The project ID will be automatically resolved from this name.<br/><br/>Naming rules:<br/>- Must start with a lowercase letter<br/>- Can contain lowercase letters, numbers, and hyphens<br/>- Must be 1-63 characters long | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(any)` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_pg_conn_str"></a> [pg\_conn\_str](#output\_pg\_conn\_str) | PostgreSQL connection string |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The ID of the Scaleway project (resolved from project\_name or provided directly). |
<!-- END_TF_DOCS -->

## Contributing

### Prerequisites

This module uses [mise](https://mise.jdx.dev/) for tool management:

```bash
# Install mise (if not already installed)
curl https://mise.run | sh

# Install required tools
mise install

# Install pre-commit hooks
pre-commit install --install-hooks
```

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run validation:
   ```bash
   tofu fmt -recursive
   tofu validate
   ```
5. Pre-commit hooks will automatically run on commit
6. Submit a merge request

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

## Disclaimer

This module is provided "as is" without warranty. Always test in non-production environments first.

---

[apache]: https://opensource.org/licenses/Apache-2.0
[apache-shield]: https://img.shields.io/badge/License-Apache%202.0-blue.svg
[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.10-623CE4
[terraform-url]: https://www.terraform.io
[scaleway-badge]: https://img.shields.io/badge/Scaleway%20Provider-%3E%3D2.64-4f0599
[scaleway-url]: https://registry.terraform.io/providers/scaleway/scaleway/
