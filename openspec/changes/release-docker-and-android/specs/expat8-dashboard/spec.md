## ADDED Requirements

### Requirement: Dashboard image is publishable to the registry
The dashboard SHALL be buildable as a Docker image and publishable to `<YOUR_REGISTRY>/expat8-dashboard` using the same `YYYYMMDD.HHMM` tag convention as the backend.

#### Scenario: Dashboard image builds successfully
- **WHEN** an operator runs `docker build` from the `expat8-dashboard/` directory
- **THEN** the multi-stage Next.js build completes and produces a runnable image

#### Scenario: Dashboard image is pushed to registry
- **WHEN** operator pushes the tagged dashboard image
- **THEN** the registry accepts it and it can be pulled by the Z440 host

#### Scenario: Dashboard container serves the admin UI
- **WHEN** the dashboard container runs with `EXPAT8_DASHBOARD_DATABASE_URL` and `BACKEND_BASE_URL` set
- **THEN** the Next.js app serves the admin UI on port 3000 and pages load without error
