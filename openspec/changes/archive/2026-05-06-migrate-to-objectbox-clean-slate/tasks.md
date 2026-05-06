## 1. Dependencies and Project Setup

- [x] 1.1 Add ObjectBox runtime/build dependencies to mobile project and remove SQLite-specific dependencies from `mobile/pubspec.yaml`.
- [x] 1.2 Configure ObjectBox code generation for Flutter (build runner + model generation workflow).
- [x] 1.3 Generate initial ObjectBox model artifacts and ensure project builds successfully.

## 2. ObjectBox Data Model and Storage Layer

- [x] 2.1 Define ObjectBox entities for local words, study events, sync queue entries, app settings, and app logs.
- [x] 2.2 Implement ObjectBox-backed local storage adapter replacing SQLite table/SQL operations.
- [x] 2.3 Implement ObjectBox query/index logic for next new word, next due review word, and bounded local word retention.
- [x] 2.4 Implement ObjectBox log persistence and pruning behavior equivalent to current product expectations.

## 3. Repository and Application Integration

- [x] 3.1 Update repository wiring to use ObjectBox-backed local storage for all read/write paths.
- [x] 3.2 Remove SQLite initialization, schema creation, and upgrade/migration branches from mobile startup and data layer.
- [x] 3.3 Enforce clean-slate behavior: do not read or migrate legacy SQLite data.
- [x] 3.4 Verify swipe/new-word/review selection flows remain behaviorally consistent with existing UX.

## 4. Testing and Validation

- [x] 4.1 Rewrite local database tests to validate ObjectBox entity persistence and query semantics.
- [x] 4.2 Update repository/session tests for refill fallback, sync queue behavior, and study-event persistence with ObjectBox.
- [x] 4.3 Run full mobile test suite and fix regressions introduced by the storage migration.
- [x] 4.4 Perform manual QA on install/upgrade scenarios to confirm clean local reset behavior.

## 5. Cleanup and Release Readiness

- [x] 5.1 Remove remaining SQLite code paths and dead utilities from the mobile module.
- [x] 5.2 Update developer documentation for ObjectBox setup, codegen, and troubleshooting.
- [x] 5.3 Add release notes describing the breaking local data reset and no-backward-compatibility policy.
