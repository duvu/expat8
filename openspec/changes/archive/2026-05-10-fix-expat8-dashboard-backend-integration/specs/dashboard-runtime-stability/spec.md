## ADDED Requirements

### Requirement: Dashboard SSR requires complete runtime credentials
The dashboard SHALL refuse to render mutation-capable server-side pages unless `APP_CREDENTIAL_APP_ID` and `APP_CREDENTIAL_SECRET` are available in the runtime environment.

#### Scenario: Missing dashboard credentials fail the render clearly
- **WHEN** the dashboard starts without `APP_CREDENTIAL_APP_ID` or `APP_CREDENTIAL_SECRET`
- **THEN** the page render fails with a clear configuration error instead of an opaque SSR crash

#### Scenario: Present dashboard credentials allow server actions
- **WHEN** the dashboard starts with both app credential values configured
- **THEN** server actions can sign backend requests and render successfully

### Requirement: Dashboard deployment variables are environment-driven
The dashboard SHALL obtain backend URL, dashboard database URL, admin token, and app credential values from runtime environment variables.

#### Scenario: Worker deployment supplies dashboard envs
- **WHEN** the dashboard is launched in the worker compose environment
- **THEN** the service receives `BACKEND_BASE_URL`, `EXPAT8_DASHBOARD_DATABASE_URL`, `ADMIN_TOKEN`, `APP_CREDENTIAL_APP_ID`, and `APP_CREDENTIAL_SECRET`

#### Scenario: Missing worker envs are surfaced during startup
- **WHEN** one of the required dashboard runtime variables is missing
- **THEN** the startup or first render path exposes the configuration issue immediately
