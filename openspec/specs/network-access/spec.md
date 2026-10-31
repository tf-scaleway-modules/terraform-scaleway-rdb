# network-access Specification

## Purpose
Private network attachment and ACL rules of the instance, including the public-access guard.

## Requirements

### Requirement: Private network attachment
When `private_network` is not null the instance SHALL have one `private_network` block with `pn_id`, `ip_net` and `enable_ipam` (default `false`); when null, no block is set.

#### Scenario: IPAM
- **WHEN** `private_network = { pn_id = "<id>", enable_ipam = true }`
- **THEN** the instance is attached to that private network with IPAM enabled

#### Scenario: No private network
- **WHEN** `private_network` is null
- **THEN** the instance has no `private_network` block

### Requirement: Private network address validation
`private_network.ip_net`, when set, SHALL be valid CIDR notation, `ip_net` and `enable_ipam = true` SHALL NOT be set together, and one of them (`ip_net` or `enable_ipam = true`) MUST be set.

#### Scenario: Invalid CIDR
- **WHEN** `private_network = { pn_id = "<id>", ip_net = "192.168.1.10" }`
- **THEN** the plan is rejected with "ip_net must be a valid CIDR notation (e.g., '192.168.1.10/24')."

#### Scenario: Static address and IPAM together
- **WHEN** `private_network = { pn_id = "<id>", ip_net = "192.168.1.10/24", enable_ipam = true }`
- **THEN** the plan is rejected with "Cannot set both ip_net and enable_ipam. Use one or the other."

#### Scenario: Neither address mode
- **WHEN** `private_network = { pn_id = "<id>" }`
- **THEN** the plan is rejected with "Set either ip_net or enable_ipam = true."

### Requirement: ACL rules
The module SHALL create one `scaleway_rdb_acl` on the instance when `acl_rules` (`map(object({ ip = string, description = string }))`, default `{}`) has at least one entry, with one `acl_rules` block per entry; when empty, no ACL resource is created.

#### Scenario: Office and VPN rules
- **WHEN** `acl_rules` has `office` (`203.0.113.0/24`) and `vpn` (`10.0.0.0/8`)
- **THEN** one ACL with two rules is planned

#### Scenario: No rules
- **WHEN** `acl_rules` is `{}`
- **THEN** no ACL resource is planned, `acl_id` is `null` and `acl_rules` is `[]`

### Requirement: ACL rule address validation
Each `acl_rules[*].ip` SHALL be valid CIDR notation.

#### Scenario: Plain IP without a prefix
- **WHEN** an ACL rule has `ip = "203.0.113.5"`
- **THEN** the plan is rejected with "ACL rule IP must be a valid CIDR notation (e.g., '192.168.1.0/24' or '10.0.0.1/32')."

### Requirement: Public access guard
A rule whose `ip` is exactly `0.0.0.0/0` SHALL be rejected at plan time unless `allow_public_access` is `true` (default `false`).

#### Scenario: Public rule without the flag
- **WHEN** `acl_rules` contains `ip = "0.0.0.0/0"` and `allow_public_access` is `false`
- **THEN** the plan fails with "ACL rule 0.0.0.0/0 (public access) is not allowed unless allow_public_access is set to true."

#### Scenario: Public rule with the flag
- **WHEN** `acl_rules` contains `ip = "0.0.0.0/0"` and `allow_public_access = true`
- **THEN** the plan succeeds and the rule is created

#### Scenario: Restricted rule
- **WHEN** `acl_rules` contains only `ip = "10.0.0.0/8"` and `allow_public_access` is `false`
- **THEN** the plan succeeds

### Requirement: ACL outputs
`acl_id` SHALL be the ID of the ACL resource or `null`, and `acl_rules` SHALL be the rules of the ACL resource or an empty list.

#### Scenario: ACL present
- **WHEN** at least one ACL rule is configured
- **THEN** `acl_id` is the ACL ID and `acl_rules` lists the applied rules

### Requirement: Wide ACL range warning
A `check` named `acl_wide_ranges` SHALL warn at plan time when `allow_public_access` is `false` and an `acl_rules[*].ip` has a prefix shorter than 8. The literal `0.0.0.0/0` is not reported by the check: the public access guard rejects it. The plan still succeeds for the warned ranges.

#### Scenario: Half of the internet
- **WHEN** `acl_rules` contains `ip = "0.0.0.0/1"` and `allow_public_access` is `false`
- **THEN** the plan succeeds with a warning from `check.acl_wide_ranges`

#### Scenario: Wide range acknowledged
- **WHEN** `acl_rules` contains `ip = "0.0.0.0/1"` and `allow_public_access = true`
- **THEN** no warning is emitted

#### Scenario: Private range
- **WHEN** `acl_rules` contains only `ip = "10.0.0.0/8"`
- **THEN** no warning is emitted

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
