## Why

SQLite is currently the storage engine for the mobile offline cache and study data, but the team wants to standardize on ObjectBox for a simpler operational model and stronger local query performance for evolving session logic. We should do this now to avoid carrying dual-database complexity while mobile learning features continue to expand.

## What Changes

- Replace SQLite-based mobile persistence with ObjectBox across local words, study events, sync queue, app settings, and app logs.
- Remove SQLite dependencies and database initialization/migration logic from the mobile app.
- Update repository/data-access code to use ObjectBox transactions, queries, and indexes.
- Keep existing user-visible behavior for learning/session flows while changing storage internals.
- **BREAKING**: No backward compatibility with existing SQLite files; existing local data is not migrated.
- **BREAKING**: App upgrade path requires clean local state (fresh install or local data reset).

## Capabilities

### New Capabilities
- `mobile-objectbox-storage`: ObjectBox-first local persistence layer for vocabulary cache, study telemetry, sync queue, settings, and logs.

### Modified Capabilities
- `mobile-local-cache-sync`: Change local persistence requirements from SQLite-based storage to ObjectBox-only storage with no legacy migration path.

## Impact

- Affected mobile code: data layer in `mobile/lib/src/data`, models used for persistence, and startup wiring.
- Affected dependencies: remove `sqflite`/`sqflite_common_ffi(_web)` usage and add ObjectBox packages/codegen.
- Testing impact: update local database tests and repository tests to validate ObjectBox behavior.
- Operational impact: release notes must explicitly state local cache reset behavior for existing installs.
