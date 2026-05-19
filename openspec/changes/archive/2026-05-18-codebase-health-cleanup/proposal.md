## Why

The codebase has grown organically and accumulated technical debt that increases maintenance burden: duplicated utility functions across modules, monolithic files exceeding 2000 lines, phantom dependencies, dead code, undocumented admin APIs, and missing dev tooling. Addressing these now prevents compounding costs as features continue to ship.

## What Changes

- **Remove dead code**: Delete unused `http_utils.js`, remove phantom `express-rate-limit` dependency, clean up no-op `telemetry.dart` sink
- **Extract shared utilities**: Pull duplicated `asyncHandler`, `bearerToken`, `resolveRequiredUserSession` into a shared backend helpers module; extract `statusForRating`, `nextReviewForRating`, `normalizeWeekStart` into shared store utilities
- **Split monolithic backend files**: Extract route groups from `app.js` (1233 lines) into separate route modules; extract seed data from `word_store.js` (2814 lines)
- **Split monolithic mobile files**: Extract DTOs from `BackendApiClient` (2059 lines) into model files; extract reusable request helper to DRY the 20+ endpoint methods
- **Add backend dev tooling**: Introduce ESLint + Prettier as devDependencies with baseline config
- **Document admin API endpoints**: Add 7+ undocumented admin endpoints to `contracts/api.md`
- **Archive completed OpenSpec changes**: Archive the 4 fully-complete changes cluttering the active list

## Capabilities

### New Capabilities
- `backend-shared-utilities`: Shared helper module for route utilities (asyncHandler, session resolution, bearer token extraction) and store utilities (rating helpers, date normalization)
- `backend-route-modules`: Route organization pattern where each domain (auth, articles, admin, learning, speaking, proficiency, study-events) lives in its own route file
- `backend-dev-tooling`: ESLint and Prettier configuration for the backend, enforcing consistent code style
- `mobile-api-layer-organization`: Extraction of DTOs into model files and shared request infrastructure in the mobile API client
- `admin-api-documentation`: Comprehensive documentation of all admin endpoints in contracts/api.md

### Modified Capabilities
- `project-consistency-governance`: Adding linting and formatting enforcement rules
- `project-documentation-hygiene`: Updating to cover admin API documentation requirements

## Impact

- **Backend**: `src/app.js`, `src/word_store.js`, `src/postgres_word_store.js`, `src/routes/exam.js`, `package.json` — structural refactoring, new files created, no behavioral changes
- **Mobile**: `lib/src/api/backend_api_client.dart` — extract DTOs and request helper, no behavioral changes
- **Contracts**: `contracts/api.md` — additions only (new admin endpoint documentation)
- **Dev workflow**: New lint/format scripts in `package.json`, new config files (`.eslintrc`, `.prettierrc`)
- **Risk**: Pure refactoring — all 319 existing tests must continue to pass unchanged
