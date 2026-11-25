## Why

The `terraform` standards store v2.1.0 requires a module to validate under both OpenTofu and Terraform, with both toolchains pinned exactly and a `validate:terraform` CI job (`terraform-providers`, `terraform-module-structure`, `terraform-repo-gitlab-ci`, `terraform-repo-mise`, `terraform-repo-precommit`). This module already declares `required_version = ">= 1.11.0"`, which both tools read, but nothing proves Terraform accepts it and the toolchain pins are loose.

## What Changes

- `openspec/config.yaml`: the `terraform` store reference moves from `v1.2.6` to `v2.1.0`; the `quality` and `repository` references stay.
- `mise.toml`: `opentofu` is pinned exactly to `1.13.10` (was `opentofu = '1.11'`) and `terraform = '1.17.2'` is added.
- `.gitlab/release.yml`: `validate:opentofu` runs `ghcr.io/opentofu/opentofu:1.13.10` (was `ghcr.io/opentofu/opentofu:1.11`); a new `validate:terraform` job (`hashicorp/terraform:1.17.2`, `terraform init -backend=false`, `terraform validate` in the root and every `examples/*/`) follows it; `create:release` lists it in `needs:`.
- `.github/workflows/ci.yml` and `release.yml` (GitHub mirror): `tofu_version` becomes `"1.13.10"`, the `mise.toml` pin (`terraform-repo-mise`, "Hooks and CI use the pinned tools"); no new GitHub job.
- `.pre-commit-config.yaml`: `terraform_fmt`, `terraform_docs` and `terraform_tflint` get `args: [--hook-config=--tf-path=tofu]`; none has it today, so with `terraform` installed the hooks would pick it instead of `tofu` (`terraform-repo-precommit`, "Terraform hooks run tofu").
- `AGENTS.md`: names OpenTofu >= 1.11.0 and Terraform >= 1.11.0; the format/validate command line gains `terraform init -backend=false && terraform validate`.

- `examples/minimal/versions.tf`, `examples/complete/versions.tf`: `required_version` `">= 1.11"` becomes `">= 1.11.0"` and the `scaleway` constraint `">= 2.89"` becomes `"~> 2.89"` (equal to the root)
- `README.md` prose outside the terraform-docs markers: line 23 (`Terraform >= 1.11 or OpenTofu >= 1.11`) and the upgrade note near line 206 that quotes `required_version` (`>= 1.11`) name `>= 1.11.0` for OpenTofu and Terraform
- Write-only and ephemeral arguments: `admin_user_password` and `user_passwords` (ephemeral, sent through `password_wo` with the `password_version` companion) need nothing for Terraform. Both OpenTofu and Terraform support ephemeral variables and `*_wo` arguments from 1.11.0, the floor already declared; the `terraform validate` job and the scratch-copy check (task 6.5) prove it before the change is applied.
- No `.tofu` file, no `language {}` block, no `lifecycle { enabled }`; the module source is untouched apart from what is listed above.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `module-contract`: the toolchain requirement ("Supported tool and provider versions") now states the support for both OpenTofu and Terraform at `>= 1.11.0`; the floor itself does not move.

## Impact

- Release level: **PATCH** (`terraform-versioning`). `required_version` stays `>= 1.11.0`, no input, output, default, resource address or provider constraint changes, nothing lands in state differently, no `moved` block. Only CI, tooling pins, docs and examples change. Consumers need no action.
- Inputs or outputs whose type, default or meaning changes: none.
- State: unchanged; the second plan after apply stays empty.
- CI: a new required job, `validate:terraform`, blocks the release when Terraform rejects the module or an example.
- Tooling: `mise install` fetches `terraform 1.17.2` and `opentofu 1.13.10`.
- Commit subject (reads as the CHANGELOG line): `Validate the module with Terraform and pin both toolchains`.
