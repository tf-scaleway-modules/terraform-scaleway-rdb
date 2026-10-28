# read-replicas Specification

## Purpose
Read replicas of the instance and their network endpoints.

## Requirements

### Requirement: Read replicas
The module SHALL create one `scaleway_rdb_read_replica` per entry of `read_replicas` (default `{}`), keyed by the map key, on the instance, with `region` (optional, default null) and `same_zone` (optional, default `false`) taken from the entry.

#### Scenario: Replica in another region
- **WHEN** `read_replicas = { replica_1 = { region = "nl-ams" } }`
- **THEN** one read replica is planned in `nl-ams` with `same_zone = false`

#### Scenario: No replicas
- **WHEN** `read_replicas` is `{}`
- **THEN** no read replica is planned

### Requirement: Replica network endpoint
A replica with a `private_network` (`pn_id`, optional `ip_net`, optional `enable_ipam` default `false`) SHALL receive a private network endpoint with those values and no direct access endpoint; a replica without `private_network` SHALL receive a direct access endpoint.

#### Scenario: Private replica
- **WHEN** a replica sets `private_network = { pn_id = "<id>", enable_ipam = true }`
- **THEN** it is planned with a private network endpoint using IPAM and no direct access endpoint

#### Scenario: Direct access replica
- **WHEN** a replica has no `private_network`
- **THEN** it is planned with a direct access endpoint

### Requirement: Replica limits and regions
At most 3 read replicas SHALL be accepted, and each replica `region`, when set, SHALL be `fr-par`, `nl-ams` or `pl-waw`.

#### Scenario: Four replicas
- **WHEN** `read_replicas` has 4 entries
- **THEN** the plan is rejected with "Maximum 3 read replicas are allowed per instance."

#### Scenario: Unsupported replica region
- **WHEN** a replica has `region = "us-east-1"`
- **THEN** the plan is rejected with "Read replica region must be one of: fr-par, nl-ams, pl-waw."

### Requirement: Replica outputs
`read_replicas` SHALL map each key to an object with `id`, `direct_access` (`ip` and `port`, or `null`) and `private_network` (`ip` and `port`, or `null`).

#### Scenario: Direct access replica output
- **WHEN** a replica without private network is created
- **THEN** its `direct_access` is the endpoint `ip` and `port` and its `private_network` is `null`

### Requirement: Replica private network address validation
A replica `private_network.ip_net`, when set, SHALL be valid CIDR notation, and one of `ip_net` or `enable_ipam = true` MUST be set. Setting both stays accepted: the static address takes precedence at the provider.

#### Scenario: Invalid replica CIDR
- **WHEN** a replica sets `private_network = { pn_id = "<id>", ip_net = "192.168.1.10" }`
- **THEN** the plan is rejected with "Read replica ip_net must be a valid CIDR notation (e.g., '192.168.1.10/24')."

#### Scenario: Replica with neither address mode
- **WHEN** a replica sets `private_network = { pn_id = "<id>" }`
- **THEN** the plan is rejected with "Read replica private_network needs ip_net or enable_ipam = true."
