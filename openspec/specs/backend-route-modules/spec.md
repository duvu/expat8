# backend-route-modules Specification

## Purpose
Ensures the backend organizes route handlers into domain-specific modules under `src/routes/`, keeping `app.js` as a thin middleware + mounting layer with no inline business logic.

## Requirements

### Requirement: Each API domain has its own route module
The backend SHALL organize route handlers into domain-specific files under `src/routes/`, each exporting a factory function that accepts dependencies and returns an Express router.

#### Scenario: Route module structure
- **WHEN** a developer looks for the handler of a `/v1/admin/*` endpoint
- **THEN** the handler is found in `src/routes/admin.js`

#### Scenario: Route module receives dependencies via factory
- **WHEN** a route module is initialized
- **THEN** the factory function receives `{ store, config, logger }` as parameters and returns an Express router

#### Scenario: app.js delegates to route modules
- **WHEN** the Express app is constructed in `app.js`
- **THEN** `app.js` mounts route modules via `router.use()` and contains no inline route handler business logic

### Requirement: Route modules exist for all API domains
The backend SHALL have separate route modules for: auth, admin, learning, articles, speaking, proficiency, study-events, content-packs, and user.

#### Scenario: All domain routes are extracted
- **WHEN** listing files in `src/routes/`
- **THEN** files exist for `auth.js`, `admin.js`, `learning.js`, `articles.js`, `speaking.js`, `proficiency.js`, `study_events.js`, `content_packs.js`, `user.js`, `exam.js`, and `helpers.js`

#### Scenario: app.js line count is reduced
- **WHEN** measuring `src/app.js` after extraction
- **THEN** the file contains fewer than 300 lines (middleware setup + router mounting only)
