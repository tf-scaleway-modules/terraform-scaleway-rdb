## ADDED Requirements

### Requirement: Replica private network address validation
A replica `private_network.ip_net`, when set, SHALL be valid CIDR notation, and one of `ip_net` or `enable_ipam = true` MUST be set. Setting both stays accepted: the static address takes precedence at the provider.

#### Scenario: Invalid replica CIDR
- **WHEN** a replica sets `private_network = { pn_id = "<id>", ip_net = "192.168.1.10" }`
- **THEN** the plan is rejected with "Read replica ip_net must be a valid CIDR notation (e.g., '192.168.1.10/24')."

#### Scenario: Replica with neither address mode
- **WHEN** a replica sets `private_network = { pn_id = "<id>" }`
- **THEN** the plan is rejected with "Read replica private_network needs ip_net or enable_ipam = true."
