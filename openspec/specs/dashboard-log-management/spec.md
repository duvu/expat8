# dashboard-log-management Specification

## Purpose
TBD - created by archiving change dashboard-log-management. Update Purpose after archive.
## Requirements
### Requirement: Admin can delete a single log archive via API
The backend SHALL expose `DELETE /v1/admin/log-archives/:id` that permanently removes the archive's content and metadata files. The endpoint requires a valid admin token.

#### Scenario: Archive is deleted successfully
- **WHEN** an admin sends `DELETE /v1/admin/log-archives/:id` with a valid admin bearer token and the archive exists
- **THEN** the backend removes both the `.log` and `.json` files and responds `204 No Content`

#### Scenario: Archive not found
- **WHEN** an admin sends `DELETE /v1/admin/log-archives/:id` with a valid admin bearer token and no archive with that ID exists
- **THEN** the backend responds `404` with `{ "error": "not_found" }`

#### Scenario: Missing or invalid admin token
- **WHEN** `DELETE /v1/admin/log-archives/:id` is called without a valid admin bearer token
- **THEN** the backend responds `403` with `{ "error": "forbidden" }`

### Requirement: Dashboard detail page provides a delete action
The dashboard archive detail page SHALL display a delete button that, on confirmation, calls the admin delete endpoint and redirects the user back to the archive list.

#### Scenario: Admin deletes an archive from the detail page
- **WHEN** an admin clicks the "Delete" button on `/ops/logs/[id]` and confirms the action
- **THEN** the dashboard invokes the Server Action, calls `DELETE /v1/admin/log-archives/:id`, and on success redirects the user to `/ops/logs`

#### Scenario: Delete fails due to backend error
- **WHEN** the delete Server Action receives a non-2xx response from the backend
- **THEN** the dashboard shows an error message to the admin and does not redirect

### Requirement: Dashboard list page provides a bulk-delete-expired action
The dashboard archive list page SHALL display a "Delete all expired" button that removes every archive whose `retention_state` is `expired` by calling the delete endpoint once per expired archive.

#### Scenario: Bulk delete removes all expired archives
- **WHEN** an admin clicks "Delete all expired" on `/ops/logs` and there are one or more expired archives
- **THEN** the dashboard calls `DELETE /v1/admin/log-archives/:id` for each expired archive, then reloads the list

#### Scenario: No expired archives to delete
- **WHEN** an admin clicks "Delete all expired" and no archives have `retention_state = expired`
- **THEN** the dashboard shows visible feedback that there are no expired archives to delete

### Requirement: Dashboard log list displays an archive stats summary
The dashboard log list page SHALL render a stats bar above the archive table showing total archive count, total storage size, active count, and expired count, derived from the full unfiltered archive list using the existing `summarizeLogArchives` utility.

#### Scenario: Stats bar is visible on list page
- **WHEN** the list page loads and at least one archive exists
- **THEN** the page displays total count, formatted total size (using `formatBytes`), active count, and expired count

#### Scenario: Stats bar with no archives
- **WHEN** the list page loads and no archives exist
- **THEN** the stats bar shows zeroed values or is hidden and does not cause a rendering error

### Requirement: Dashboard log list supports filtering by user ID
The dashboard archive list page SHALL include a User filter input that narrows the displayed archives to those whose `source_user_id` exactly contains the entered value (case-insensitive substring match), integrated with the existing `filterLogArchives` client-side filter.

#### Scenario: Admin filters by user ID
- **WHEN** an admin enters a user ID substring in the User filter field and submits the form
- **THEN** the list shows only archives whose `source_user_id` contains the entered substring

#### Scenario: User filter is cleared
- **WHEN** an admin clears the User filter field and submits the form
- **THEN** the list shows all archives subject to other active filters only

