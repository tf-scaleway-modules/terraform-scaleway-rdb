## MODIFIED Requirements

### Requirement: Clone public endpoint
With `clone_from` set and `private_network` null, the instance SHALL carry an empty `load_balancer` block so the public endpoint created by the clone is kept; with `private_network` set it SHALL carry one only when `public_endpoint` is `true`. Without `clone_from` and with `public_endpoint` `false` no `load_balancer` block is set.

#### Scenario: Public clone
- **WHEN** `clone_from` is set and `private_network` is null
- **THEN** the instance has one `load_balancer` block and `connection_host` resolves from it

#### Scenario: Private clone
- **WHEN** `clone_from` is set, `private_network = { pn_id = "<id>", enable_ipam = true }` and `public_endpoint` is `false`
- **THEN** the instance has the private network block and no `load_balancer` block

#### Scenario: Not a clone
- **WHEN** `clone_from` is null and `public_endpoint` is `false`
- **THEN** the instance has no `load_balancer` block

## ADDED Requirements

### Requirement: Public endpoint next to a private network
`public_endpoint` (`bool`, default `false`) SHALL keep or add a public endpoint (an empty `load_balancer` block) on an instance that also has a `private_network`. It MUST be `false` when `private_network` is null, because the instance is then always public.

#### Scenario: Hybrid access
- **WHEN** `private_network = { pn_id = "<id>", enable_ipam = true }` and `public_endpoint = true`
- **THEN** the instance has the private network block and one `load_balancer` block, and both `instance_load_balancer` and `instance_private_network` are populated

#### Scenario: Private only by default
- **WHEN** `private_network` is set and `public_endpoint` is left at `false`
- **THEN** the instance has no `load_balancer` block

#### Scenario: Public endpoint without a private network
- **WHEN** `public_endpoint = true` and `private_network` is null
- **THEN** the plan fails with "public_endpoint requires private_network: an instance without one is always public."
