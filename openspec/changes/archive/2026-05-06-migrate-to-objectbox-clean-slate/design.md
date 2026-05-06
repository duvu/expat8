## Context

The mobile app currently persists learning data with SQLite via `sqflite`, with tables for words, study events, sync queue, settings, and logs. The team wants a clean storage reset and a full switch to ObjectBox, without preserving legacy SQLite files or compatibility logic.

This change affects core mobile data paths (`local_database`, repository refill/sync flow, and tests) and introduces a new persistence runtime and codegen workflow.

## Goals / Non-Goals

**Goals:**
- Replace SQLite persistence with ObjectBox for all mobile local data domains.
- Remove SQLite runtime dependencies, schema SQL, and migration branches.
- Keep existing user-facing learning/session behavior stable.
- Ship a clean-slate rollout with no backward data migration.

**Non-Goals:**
- Migrating existing user SQLite data into ObjectBox.
- Introducing backend API changes for this migration.
- Supporting dual-read/dual-write or runtime fallback between SQLite and ObjectBox.

## Decisions

### Decision 1: ObjectBox-only storage engine
- Use ObjectBox entities/boxes for local words, study events, sync queue, settings, and logs.
- Rationale: simpler long-term data layer than maintaining SQL schema + migration scripts.
- Alternative considered: keep SQLite with refactoring only. Rejected because it does not meet the objective of removing SQLite entirely.

### Decision 2: Clean cutover with destructive local reset semantics
- App startup creates/opens ObjectBox store only; SQLite file is ignored.
- Rationale: avoids fragile migration code and inconsistent edge cases across app versions.
- Alternative considered: one-time SQLite-to-ObjectBox migration. Rejected per explicit product direction (no backward compatibility).

### Decision 3: Keep repository/service contracts stable
- `WordRepository` and session logic preserve behavioral contract while internals switch adapters.
- Rationale: minimizes feature regressions in swipe/session UX while replacing persistence backend.
- Alternative considered: redesign repository API. Rejected to reduce blast radius.

### Decision 4: Add ObjectBox-focused test coverage
- Replace DB tests that assert SQL behavior with entity/box behavior and repository-level flows.
- Rationale: protect critical session paths and sync behavior during storage replacement.

## Risks / Trade-offs

- [Existing local data loss on upgrade] -> Mitigation: explicit release notes and in-app communication before rollout.
- [Regression in swipe/new-word flow due to persistence adapter changes] -> Mitigation: repository integration tests for fallback/new/review selection.
- [ObjectBox codegen/build misconfiguration] -> Mitigation: add CI step for code generation and fail-fast checks.
- [Operational debugging gap during migration] -> Mitigation: keep structured app log events and validate log persistence in ObjectBox.

## Migration Plan

1. Add ObjectBox dependencies and codegen setup to mobile project.
2. Introduce ObjectBox entities and storage adapter replacing SQLite table operations.
3. Update repository wiring to consume ObjectBox-backed database implementation.
4. Remove SQLite dependencies and obsolete SQL schema/migration code.
5. Update and run tests for local storage, repository, and session flows.
6. Ship with release notes stating local cache reset behavior.

Rollback strategy: revert to previous mobile release binary; no runtime fallback is provided in this change.

## Open Questions

- Do we need an in-app one-time notice specific to local cache reset, or are release notes sufficient?
- Should app logs in ObjectBox keep the same retention limit (`maxEntries`) or be tuned after migration metrics?
