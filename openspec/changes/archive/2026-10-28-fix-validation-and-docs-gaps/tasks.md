## 1. Code

- [x] 1.1 `locals.tf`: resolve `project_id` with `one()` so no project input works
- [x] 1.2 `main.tf`: `backup_same_region` is `null` when backups are disabled
- [x] 1.3 `variables.tf`: `admin_user_password_wo` ephemeral; validations for `private_network` and replica `private_network`
- [x] 1.4 `checks.tf`: `acl_wide_ranges` and `manual_backup_volume_size` checks
- [x] 1.5 Descriptions: `tags`, `volume_size_in_gb`, `logs_policy`, `private_network`, `privileges`, `manual_backups`, `allow_public_access`, `acl_rules`, `users`, output `admin_password`

## 2. Tests, example, docs

- [x] 2.1 `tests/main.tftest.hcl`: mock provider; happy path, no-project plan, org-only rejection, rejected input per new validation, one run per check, backups-disabled run
- [x] 2.2 `examples/complete`: admin password through `admin_user_password_wo`
- [x] 2.3 `SECURITY.md`: what lands in state and the `users[*].password_wo` limit; README Security Features line for the wide ACL warning

## 3. Verify

- [x] 3.1 `tofu fmt -recursive`, `tofu init -backend=false`, `tofu validate`, `tofu test`
- [x] 3.2 `tflint --recursive`, `pre-commit run -a`, `openspec validate --all --strict`
- [x] 3.3 Commit subject: "Fix project resolution, add ACL and backup size warnings, require a private network address mode"
