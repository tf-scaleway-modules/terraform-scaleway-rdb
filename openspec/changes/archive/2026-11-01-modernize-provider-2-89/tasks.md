# Tasks

## 1. Inputs and project (variables.tf, data.tf, locals.tf, main.tf)
- [x] 1.1 Remove `organization_id`, `project_name`, `data.scaleway_account_project.this`, `locals.project_id` and the project precondition; keep `project_id` (UUID validation); pass `project_id = var.project_id`
- [x] 1.2 Add `volume` and `backup` objects (defaults and messages as in the spec), remove the six flat inputs; update the instance arguments, the block-storage precondition, the clone guard and `checks.tf` (`volume.size_in_gb`)
- [x] 1.3 Change `tags` to `list(string)` (default `[]`); `tags = distinct(var.tags)`; remove `locals.tags_list`
- [x] 1.4 Remove `lifecycle.prevent_destroy`; remove `locals` entries now unused (`is_mysql`, `database_ids`, `user_info`, `default_port` if inlined)

## 2. Passwords
- [x] 2.1 Add `admin_user` object and ephemeral `admin_user_password`; remove the four old admin inputs; update the admin and clone preconditions and messages
- [x] 2.2 Remove `users[*].password`, `password_wo`, `password_wo_version`; add `users[*].password_version` (default 1) and ephemeral `user_passwords`; validations: key subset, complexity; per-user precondition on `scaleway_rdb_user.this`
- [x] 2.3 Verify `tofu test` accepts the preconditions that read ephemeral variables; if not, move them to `validation` blocks (design D2)

## 3. Network
- [x] 3.1 Add `public_endpoint` (bool, default `false`), its precondition, and the `load_balancer` condition (design D5)

## 4. Outputs
- [x] 4.1 Remove the 12 outputs listed in the proposal; `project_id` from the instance; `connection_host`/`connection_port` with private fallback; `engine_type` without `unknown`
- [x] 4.2 Add `hostname` to `read_replicas` endpoints; inline the map outputs

## 5. Tests (tests/main.tftest.hcl, mock_provider "scaleway")
- [x] 5.1 Remove the project-lookup override and runs; add `project_id` null/valid runs
- [x] 5.2 Rejected-input runs: invalid `project_id`; `admin_user` without password and the reverse; admin with `clone_from`; `user_passwords` unknown key; user without password; weak admin and user passwords; `volume` block storage without size / bad type / bad size; `backup` frequency and retention out of range; `public_endpoint` without `private_network` (a `tags` map and the removed `organization_id` are not expressible with `expect_failures`: type errors and undeclared inputs fail the run itself)
- [x] 5.3 Happy runs: write-only admin and user passwords reach `password_wo`/`password_wo_version`; `backup.enabled = false` sends no schedule; hybrid endpoint has `load_balancer` and `private_network`; private-only has no `load_balancer`; tags de-duplicated; the 17 outputs are populated (the removed ones are absent: 17 `output` blocks); replica `hostname`
- [x] 5.4 Keep and adapt the clone, ACL, manual backup and check runs (`volume.*`, `admin_user`)

## 6. Examples and docs
- [x] 6.1 `examples/minimal`: ephemeral `admin_user_password`, `user_passwords`, `volume`/`backup` objects, list tags
- [x] 6.2 `examples/complete`: `project_id`, `user_passwords`, `public_endpoint` + `private_network` behind a variable, clone, list tags
- [x] 6.3 README: "Upgrading from v2 to v3" section with the consumer edit for every breaking change in the proposal (replace "Upgrading to v2.0.0"), Features, Security Features, what lands in state; never touch `BEGIN_TF_DOCS`/`END_TF_DOCS`
- [x] 6.4 `SECURITY.md` state table (no password in state or plan), `AGENTS.md` and `openspec/config.yaml` module-specific lines (project, password and tags wording)

## 7. Validation (report output as-is)
- [x] 7.1 `mise exec -- tofu fmt -recursive`
- [x] 7.2 `mise exec -- tofu init -backend=false && mise exec -- tofu validate`
- [x] 7.3 `mise exec -- tflint --recursive`
- [x] 7.4 `mise exec -- tofu test`
- [x] 7.5 Move a local `.terraform.lock.hcl` aside, then `mise exec -- pre-commit run -a` (terraform-docs would print the locked version)
- [x] 7.6 `mise exec -- openspec validate --all --strict`

## 8. Commit
- [x] 8.1 Subject: `Send every password write-only, group instance inputs into objects, add a public endpoint and trim outputs`; body starts `BREAKING:` and lists the removed inputs/outputs and the `tags` type change; next tag `v3.0.0`

## 9. Real-account checks (manual, only with the user's approval; not part of the unit suite)
- [ ] 9.1 Plan v3 against a v2 state of an instance with plain admin and user passwords: expect in-place updates only, no replacement, no address change; apply, then second plan empty
- [ ] 9.2 Plan a v2 instance with converted `tags`, `volume`, `backup`: empty plan
- [ ] 9.3 Add `public_endpoint = true` to a private instance: in-place endpoint creation, second plan empty; remove it again
- [ ] 9.4 Rotate `admin_user.password_version`: password changes, second plan empty
