## ADDED Requirements

### Requirement: Dashboard continues to use backend admin APIs
The dashboard SHALL use the existing `expat8-backend` admin endpoints for article mutations, vocabulary review mutations, and speaking-prompt mutation flows.

#### Scenario: Dashboard mutation requests are signed and authorized
- **WHEN** an admin submits a dashboard mutation
- **THEN** the dashboard sends the request with the required app credentials and admin token

#### Scenario: Speaking prompt review stays on the backend contract
- **WHEN** an admin opens or edits the speaking-prompts page
- **THEN** the dashboard reads and writes data using the backend speaking-prompt API contract

### Requirement: Dashboard pages remain available in the worker deployment
The dashboard SHALL load the article list, article detail, vocabulary review, and speaking-prompts review pages against the live worker backend and database.

#### Scenario: Dashboard pages load against the live worker backend
- **WHEN** the worker deployment is healthy and the backend schema is current
- **THEN** the dashboard pages render without server-side exceptions

#### Scenario: Backend schema drift is visible during verification
- **WHEN** the backend database is missing required tables or indexes
- **THEN** rollout verification fails before the dashboard is considered ready

### Requirement: Dashboard rollout verifies backend compatibility
The deployment process SHALL verify the dashboard against the live backend and database before the change is marked ready.

#### Scenario: Dashboard smoke test runs after deploy
- **WHEN** a new dashboard build is deployed
- **THEN** the rollout includes a smoke test that loads the dashboard and checks the backend-admin flows

#### Scenario: Backend speaking routes are checked during rollout
- **WHEN** the dashboard rollout reaches verification
- **THEN** the speaking-prompts route and speaking-summary-dependent flows are checked against the worker backend
