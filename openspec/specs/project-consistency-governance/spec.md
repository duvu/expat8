# project-consistency-governance Specification

## Purpose
TBD - created by archiving change resolve-codebase-consistency-drift. Update Purpose after archive.
## Requirements
### Requirement: Current project documentation follows canonical sources
The project SHALL keep current, non-dated developer documentation aligned with accepted OpenSpec specs and `contracts/api.md`.

#### Scenario: API behavior changes
- **WHEN** an API endpoint, method, parameter, response shape, or status code changes
- **THEN** `contracts/api.md` and current setup documentation are updated in the same change

#### Scenario: Current setup documentation describes runtime behavior
- **WHEN** `README.md`, `mobile/README.md`, or `docs/mvp-setup.md` describes storage, endpoints, or setup prerequisites
- **THEN** the documentation reflects the current runnable system rather than an archived or superseded design

#### Scenario: Historical investigation remains in the repo
- **WHEN** a dated investigation document describes an obsolete route, storage engine, or workflow
- **THEN** the document is marked as historical and not a current source of truth

### Requirement: OpenSpec active changes reflect current project state
The project SHALL keep active OpenSpec changes synchronized with implemented architecture decisions or explicitly mark stale sections as superseded.

#### Scenario: Completed change remains active
- **WHEN** an OpenSpec change has all implementation tasks complete
- **THEN** the change is archived or explicitly left active with a reason and remaining follow-up tasks

#### Scenario: Later change supersedes an earlier active artifact
- **WHEN** a later accepted change replaces an endpoint, storage engine, or workflow mentioned by an earlier active artifact
- **THEN** the earlier artifact is updated to reference the superseding change instead of presenting the old behavior as current

### Requirement: Cross-project API fields have an explicit lifecycle
Every API field, query parameter, and header used by mobile or backend SHALL be either implemented, reserved, or removed across code, contracts, tests, and docs.

#### Scenario: New API parameter is introduced
- **WHEN** a change adds a request field or query parameter
- **THEN** the contract documents it, backend validates or uses it, mobile sends it intentionally, and tests cover accepted and rejected values

#### Scenario: Existing API parameter is ignored
- **WHEN** a parameter is no longer read by the backend or no longer needed by mobile
- **THEN** the parameter is removed from mobile and current docs, or documented as reserved with tests proving the intended behavior

