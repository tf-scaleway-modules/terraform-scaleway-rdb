# Tasks

Standards: `terraform-versioning`, `terraform-providers`, `terraform-variables`, `terraform-outputs`, `terraform-security`, `terraform-testing`, `terraform-code-style`, `quality-*`. Fetch `terraform-code-style`, `terraform-variables` and `terraform-outputs` before editing HCL. Do not run `tofu apply` against a real account unless the user asks; say so when skipped.

## 1. Provider floor and clone source

- [x] 1.1 `versions.tf`: `version = "~> 2.89"`; verify `tofu init -backend=false -upgrade && tofu validate` pass.
- [x] 1.2 `variables.tf`: add `clone_from` (`string`, default `null`, UUID or `<region>/<UUID>` validation, description with: engine/admin user rules, source-matching inputs, public endpoint, `project_id` not applied, users/databases already in the source, **forces replacement on an existing instance**); make `engine` default `null` with validation `engine == null || regex`, reorder so `node_type` (required) precedes optional `engine`/`clone_from`; update `engine` description (engine upgrade: blue/green, writes lost, second apply for ACL, never re-apply during an upgrade). Verify with `tofu validate`.
- [x] 1.3 `data.tf`: `data "scaleway_rdb_instance" "source"` (`count = var.clone_from != null ? 1 : 0`, `instance_id`, `region`). `locals.tf`: `engine` local, `is_postgresql`/`is_mysql` use it. Verify with `tofu validate`.
- [x] 1.4 `main.tf`: `clone_from = var.clone_from`; `dynamic "load_balancer"` only when cloning without `private_network`; preconditions (engine xor clone_from; no admin user with clone; storage/encryption/init_settings equal source; HA source needs `is_ha_cluster = true`) with the exact messages of the delta specs; `timeouts.update = "60m"`. Verify with `tofu validate` and `tflint --recursive`.
- [x] 1.5 Unit tests in `tests/main.tftest.hcl` (`mock_provider "scaleway"`, add `override_data` for `data.scaleway_rdb_instance.source` with `volume_type`, `volume_size_in_gb`, `encryption_at_rest`, `is_ha_cluster`, `init_settings`): clone plan succeeds (no `engine`, `clone_from` set, public `load_balancer` block, update timeout `60m`); clone with `private_network` has no `load_balancer`; non-clone has none. Rejected-input runs with `expect_failures`: invalid `clone_from` (`var.clone_from`), neither/both of `engine` and `clone_from`, admin user with clone, `sbs_5k` source with default `volume_type`, unencrypted source with default `encryption_at_rest`, HA source with default `is_ha_cluster`; `engine = "PostgreSQL-10"` still rejected; `engine_type` for a clone follows the mocked instance engine. Verify `tofu test` passes.

## 2. Manual backup expiry

- [x] 2.1 `variables.tf`: `manual_backups[*].expires_at` `optional(string)` (default null) with the UTC `...Z` validation and description (cannot be removed once set); `main.tf`: `expires_at = each.value.expires_at`; `outputs.tf`: `expires_at` in `manual_backups`. Verify with `tofu validate`.
- [x] 2.2 Tests: happy path with `expires_at = "2027-01-31T00:00:00Z"` (planned value and output); rejected runs for an offset timestamp and `"next week"` (`expect_failures = [var.manual_backups]`). Verify `tofu test` passes.

## 3. Examples, docs, security notes

- [x] 3.1 `examples/complete`: add an opt-in clone (`enable_staging_clone` bool, default `false`, module call with `count`, `clone_from = module.production_database.instance_id`, `volume_type`/`volume_size_in_gb`/`is_ha_cluster` matching the source, no `engine`, no admin user), `expires_at` on a manual backup, `update` note; keep `examples/minimal` unchanged. Verify `tofu init -backend=false && tofu validate` in both example directories.
- [x] 3.2 `README.md` prose (never inside `BEGIN_TF_DOCS`/`END_TF_DOCS`): provider prerequisite and badge `>= 2.89`; "Clone an instance" section (what is inherited, what must match, public endpoint, users/databases already present, replacement warning); engine upgrade notes; **upgrade note for v2.0.0**: provider floor raised to `~> 2.89` because `clone_from` needs it, run `tofu init -upgrade`, no input removed. Check `SECURITY.md` "what lands in state": clone and `expires_at` add no secret, state the clone takes no password.
- [x] 3.3 Known pitfall: a local `.terraform.lock.hcl` makes terraform-docs write the locked provider version instead of the constraint into the README. Move the lock file aside (outside the repo tree) before `pre-commit run -a` and before pushing, then verify the README table shows `~> 2.89`.

## 4. Verify

- [x] 4.1 `tofu fmt -recursive`, `tofu init -backend=false && tofu validate`, `tflint --recursive`, `tofu test`: all pass, output reported as-is.
- [x] 4.2 `pre-commit run -a` (terraform-docs regenerates the README block; lock file moved aside per 3.3) passes; `mise run spec-validate` and `openspec validate update-provider-2-89 --strict` pass.
- [ ] 4.3 Confirm against a real account only if the user approves: a plan of an existing state with provider 2.89 is empty; a clone apply has an empty second plan (confirms the HA and `init_settings` guards, relax the HA guard to a `check` if the provider handles it safely). If not run, report it as skipped. (skipped: no credentials; not run)
- [x] 4.4 Commit subject that reads as the CHANGELOG line: `Add clone_from and manual backup expiry, raise the Scaleway provider floor to 2.89`. Body: **BREAKING** provider floor `~> 2.86` → `~> 2.89` (`clone_from` needs 2.89.0; run `tofu init -upgrade`), `engine` now optional, update timeout 30m → 60m. Next tag `v2.0.0` (release: `mise run changelog`).

## Workflow follow-up

- Archive the change after review (`/openspec-archive-change`); the main specs `instances`, `network-access`, `backups` and `module-contract` change, no requirement is removed.
