## ADDED Requirements

### Requirement: Clone public endpoint
With `clone_from` set and `private_network` null, the instance SHALL carry an empty `load_balancer` block so the public endpoint created by the clone is kept; with `private_network` set it SHALL carry no `load_balancer` block, so the clone is reachable on the private network only. Without `clone_from` no `load_balancer` block is set.

#### Scenario: Public clone
- **WHEN** `clone_from` is set and `private_network` is null
- **THEN** the instance has one `load_balancer` block and `connection_host` resolves from it

#### Scenario: Private clone
- **WHEN** `clone_from` is set and `private_network = { pn_id = "<id>", enable_ipam = true }`
- **THEN** the instance has the private network block and no `load_balancer` block

#### Scenario: Not a clone
- **WHEN** `clone_from` is null
- **THEN** the instance has no `load_balancer` block
