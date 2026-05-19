# backend-shared-utilities Specification

## Purpose
Ensures that shared utility functions used across route handlers and store implementations are defined exactly once, eliminating duplication and establishing single canonical import locations.

## Requirements

### Requirement: Route helper utilities are defined in a single shared module
The backend SHALL define `asyncHandler`, `bearerToken`, `resolveRequiredUserSession`, and `resolveOptionalUserSession` in exactly one module (`src/routes/helpers.js`) and all route files SHALL import from that module.

#### Scenario: Route file needs async error handling
- **WHEN** a route handler is async and may throw
- **THEN** it wraps the handler with `asyncHandler` imported from `src/routes/helpers.js`

#### Scenario: Route file needs session resolution
- **WHEN** a route handler requires an authenticated user session
- **THEN** it calls `resolveRequiredUserSession` imported from `src/routes/helpers.js`

#### Scenario: No duplicated utility definitions exist
- **WHEN** the codebase is searched for definitions of `asyncHandler`, `bearerToken`, or `resolveRequiredUserSession`
- **THEN** each function is defined in exactly one file (`src/routes/helpers.js`)

### Requirement: Store utility functions are defined in a single shared module
The backend SHALL define `statusForRating`, `nextReviewForRating`, and `normalizeWeekStart` in exactly one module (`src/store_utils.js`) and both store implementations SHALL import from that module.

#### Scenario: In-memory store calculates next review
- **WHEN** `WordStore` needs to compute the next review date for a rating
- **THEN** it calls `nextReviewForRating` imported from `src/store_utils.js`

#### Scenario: Postgres store calculates status from rating
- **WHEN** `PostgresWordStore` needs to derive status from a rating value
- **THEN** it calls `statusForRating` imported from `src/store_utils.js`

#### Scenario: No duplicated store utility definitions exist
- **WHEN** the codebase is searched for definitions of `statusForRating`, `nextReviewForRating`, or `normalizeWeekStart`
- **THEN** each function is defined in exactly one file (`src/store_utils.js`)
