# Tasks

## 1. Tooling

- [x] 1.1 Pin `node` and `"npm:@fission-ai/openspec"` in `mise.toml`, add the `spec-validate` and `spec-setup` tasks and `scripts/openspec-setup.sh`
- [x] 1.2 Add `.gitlab/specs.yml` (`validate:specs`), include it in `.gitlab-ci.yml` and set `OPENSPEC_VERSION` in `.gitlab/global.yml`
- [x] 1.3 Install the `openspec-*` skills in `.claude/skills/` and `.opencode/skills/`

## 2. OpenSpec configuration

- [x] 2.1 Fill `openspec/config.yaml` `context` with scaleway-rdb facts (project, stack, layout, conventions, commands) and adapt the `rules` and `operations` to the git-cliff CHANGELOG and the absence of `tests/`; keep `references:` unchanged
- [x] 2.2 Fill `AGENTS.md` (title, Project, Module-specific, Commands) and keep the profile's other sections
- [x] 2.3 `CLAUDE.md` imports `AGENTS.md`

## 3. Baseline specs

- [x] 3.1 Write the delta specs `module-contract`, `instances`, `databases-and-users`, `network-access`, `backups`, `read-replicas` from `variables.tf`, `main.tf`, `locals.tf`, `data.tf` and `outputs.tf`, with a scenario for every `validation` and `precondition` block
- [x] 3.2 `openspec validate --all --strict` passes (same command as the `validate:specs` CI job)
- [x] 3.3 Archive the change (`openspec archive adopt-openspec --yes`) and replace the `TBD` purposes with real ones; validate strictly again

## 4. Documentation and checks

- [x] 4.1 README "Contributing" describes the OpenSpec workflow (`mise run spec-setup`, `mise run spec-validate`), outside the terraform-docs markers
- [x] 4.2 `pre-commit run --files $(git diff --cached --name-only --diff-filter=d)` passes
- [x] 4.3 No `.tf` file, example or `CHANGELOG.md` changed
