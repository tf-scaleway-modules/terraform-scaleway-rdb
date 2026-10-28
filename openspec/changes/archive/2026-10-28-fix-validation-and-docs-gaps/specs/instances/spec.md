## MODIFIED Requirements

### Requirement: Project resolution
The project of the instance SHALL be `project_id` when set; otherwise the ID of the project found by looking up `project_name` in `organization_id` (a `scaleway_account_project` data source, read only when both `organization_id` and `project_name` are set); when none of the three inputs is set, no project is sent and the provider's default project applies. The resolved ID is exposed as the `project_id` output.

#### Scenario: Direct project ID
- **WHEN** `project_id` is set
- **THEN** the instance is created in that project and no data source lookup is made

#### Scenario: Lookup by name
- **WHEN** `organization_id` and `project_name` are set and `project_id` is null
- **THEN** the project is looked up by name in the organization and its ID is used for the instance

#### Scenario: No project input
- **WHEN** `project_id`, `organization_id` and `project_name` are all null
- **THEN** the plan succeeds and the instance receives no `project_id`, so the provider default project applies
