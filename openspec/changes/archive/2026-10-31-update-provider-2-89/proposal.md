# Proposal

## Why

Scaleway provider 2.89.0 (released 2026-10-27) adds `clone_from` to `scaleway_rdb_instance`: a new
instance that starts as an independent copy (databases, users, permissions) of an existing one.
The module cannot express it today (`engine` is required, the admin user and storage arguments
would fight the inherited values). A gap analysis of the seven resources and the data source the
module uses against 2.89.0 also found one under-sized timeout, one unexposed argument worth exposing
(`expires_at` of manual backups) and one undocumented upgrade pitfall.
See `design.md` for the full list of what was considered.

## What Changes

- **New input `clone_from`** (string, default `null`; instance ID or `<region>/<id>`): creates the instance
  as a clone of that instance. Introduced by provider **2.89.0** (not in 2.86.0).
- **`engine` becomes optional** (default `null`). Exactly one of `engine` and `clone_from` MUST be set
  (the provider makes them conflict). Existing configurations that set `engine` are unchanged.
- Clone mode guards (preconditions on the instance, rejected with a message instead of a perpetual diff
  or an apply-time provider error): no `admin_user_name`/password (the clone keeps the source's users);
  `volume_type`, `volume_size_in_gb`, `encryption_at_rest` and `init_settings` equal to the source's;
  `is_ha_cluster = true` for an HA source. A `scaleway_rdb_instance` data source (read only when
  `clone_from` is set) supplies the source values.
- In clone mode without `private_network`, the instance keeps the public endpoint that `CloneInstance`
  creates (`load_balancer {}`); with `private_network` it is private-only, as for a non-clone instance.
- `engine_type`, `engine_default_port` follow the instance's `engine` attribute when `engine` is null.
- **Update timeout 30m → 60m** on the instance (provider default; the docs warn that a blue/green engine
  upgrade that times out leaves orphaned instances and a stale state). Provider docs identical in 2.86.0.
- **`manual_backups[*].expires_at`** (optional, default `null`, UTC `YYYY-MM-DDTHH:MM:SSZ`): expiry of a manual
  backup, so backups do not accumulate and bill forever. Argument exists since before 2.86 (docs identical in
  2.86.0 and 2.89.0), so it does not need the new floor. The `manual_backups` output gains `expires_at`.
- Documentation: engine upgrade notes (blue/green, writes between snapshot and switch are lost, `scaleway_rdb_acl`
  may need a second apply), clone usage and limits, README provider floor.
- **BREAKING (semver major)**: the provider floor is raised from `~> 2.86` to `~> 2.89` because `clone_from`
  does not exist in 2.86.0 (`terraform-versioning`, `terraform-providers`: raised floor = major; next tag
  `v2.0.0`, last is `v1.2.2`). No input, output, default or resource address is removed or renamed.

Inputs/outputs whose type, default or meaning changes: `engine` (required → optional, `null` default,
validation accepts `null` only with `clone_from`); new `clone_from`; `manual_backups` (new optional `expires_at` attribute and output key); `engine_type` and `engine_default_port`
(derived from the instance when `engine` is null; same values otherwise); input count 31 → 32, output count stays 29.

State: nothing secret-bearing is added (`terraform-security`): clone mode takes no password. Existing state
migrates in place (no schema bump, no address change, no `moved` block). Setting `clone_from` on an
**existing** instance forces replacement (provider `ForceNew`), documented in the input description.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `instances`: clone from an existing instance, optional `engine`, clone-mode guards, 60 minute update timeout.
- `network-access`: public endpoint of a clone.
- `backups`: optional manual backup expiry, `expires_at` output key.
- `module-contract`: provider floor `~> 2.89`, input counts and defaults, engine helper outputs.

## Impact

`versions.tf`, `main.tf`, `data.tf`, `locals.tf`, `variables.tf`, `tests/main.tftest.hcl`,
`examples/complete`, `README.md` (generated block plus prose), `SECURITY.md` (state table: clone adds none).
Consumers must be able to resolve provider >= 2.89.0 (`tofu init -upgrade`).
Standards applied: `terraform-versioning`, `terraform-providers`, `terraform-variables`,
`terraform-security`, `terraform-testing`, `terraform-outputs`, `quality-simplicity`,
`quality-efficiency`, `quality-security`, `quality-production-readiness`.
