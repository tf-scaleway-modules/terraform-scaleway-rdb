## MODIFIED Requirements

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

## ADDED Requirements

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
