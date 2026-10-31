## MODIFIED Requirements

### Requirement: Replica outputs
`read_replicas` SHALL map each key to an object with `id`, `direct_access` (`ip`, `port` and `hostname`, or `null`) and `private_network` (`ip`, `port` and `hostname`, or `null`).

#### Scenario: Direct access replica output
- **WHEN** a replica without private network is created
- **THEN** its `direct_access` is the endpoint `ip`, `port` and `hostname` and its `private_network` is `null`

#### Scenario: Private replica output
- **WHEN** a replica with a private network is created
- **THEN** its `private_network` carries `ip`, `port` and `hostname` and its `direct_access` is `null`
