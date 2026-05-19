## MODIFIED Requirements

### Requirement: Current project documentation follows canonical sources
The project SHALL keep current, non-dated developer documentation aligned with accepted OpenSpec specs and `contracts/api.md`. Additionally, the backend SHALL enforce code style consistency through automated linting and formatting tools.

#### Scenario: API behavior changes
- **WHEN** an API endpoint, method, parameter, response shape, or status code changes
- **THEN** `contracts/api.md` and current setup documentation are updated in the same change

#### Scenario: Current setup documentation describes runtime behavior
- **WHEN** `README.md`, `mobile/README.md`, or `docs/mvp-setup.md` describes storage, endpoints, or setup prerequisites
- **THEN** the documentation reflects the current runnable system rather than an archived or superseded design

#### Scenario: Historical investigation remains in the repo
- **WHEN** a dated investigation document describes an obsolete route, storage engine, or workflow
- **THEN** the document is marked as historical and not a current source of truth

#### Scenario: Backend code style is enforced by tooling
- **WHEN** a developer submits backend code changes
- **THEN** `npm run lint` reports zero errors and `npm run format:check` reports zero unformatted files
