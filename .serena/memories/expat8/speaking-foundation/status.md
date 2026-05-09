# Speaking Foundation — Phase 0-3 Status

## Status: COMPLETE (all tasks 1.1–9.7 done and committed)

## Branch
`x51-commit/20260509-204126-speaking-foundation-impl` (commit `06811a2`)

## What Was Done
All 59 tasks in `openspec/changes/add-speaking-foundation/tasks.md` are checked **except**:
- 9.3 — migration verifier against live DB (needs `DATABASE_URL=...` env)
- 9.8 — smoke test mixed rating/speaking batch against running backend
- 9.9 — release notes / beta rollout docs (out of scope)

## Verification Results
- `flutter test`: 133 passed, 0 failed
- `tsc --noEmit` (expat8-dashboard): 0 errors
- Backend tests: 96 passed, 2 skipped, 0 failed (from prior session; backend unchanged)

## Key Fix Applied
ObjectBox cross-test data leakage in `Drill selection` test group:
- Root cause: shared `databaseName: 'drill_selection_test.db'` across setUp/tearDown cycles; ObjectBox persists data to disk; closing the store does NOT delete data
- Fix: `var _drillTestCounter = 0` counter inside the group; each `setUp` uses `drill_selection_test_$_drillTestCounter.db`
- File: `mobile/test/speaking_test.dart` lines 245-260

## Feature Flag
`speakingFoundationEnabled` (default false) in `mobile/lib/src/config.dart`. Flip to `true` to activate speaking UI.

## Remaining
- Run `DATABASE_URL=<live_db_url> npm run verify:migrations` in `backend/` before merging to main
- Smoke test mixed batch sync (`POST /v1/study-events/sync` with speaking events) against local/dev stack
- Merge branch to main when ready for beta rollout
