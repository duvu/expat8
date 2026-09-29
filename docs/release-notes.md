# Release Notes

Per-version change lists (PR links) are generated on [GitHub Releases](https://github.com/duvu/expat8/releases). This file keeps the operator view: what each mobile release needs from the backend. **Deploy the backend listed before publishing the app** ([ops/mobile-release.md](ops/mobile-release.md)).

| App | Date | Highlights | Backend requirement |
|---|---|---|---|
| 1.3.4+8 | 2026-09-29 | Simpler UI for all main screens: study action bar, friendly statuses, language picker (#42, #43) | Same as 1.3.3 |
| 1.3.3+7 | 2026-09-28 | Word Blaster game (#39), Sudoku on Flame (#25) | Backend with `POST /v1/games/rounds`, `GET /v1/games/leaderboard` and migration `20260929_games_rounds_and_event_source`. Older backend → game rounds get 404 and are dropped from the sync queue |
| 1.3.2 | 2026-09-28 | Offline-first app: every feature works offline, sync on reconnect, anonymous history claimed on sign-in (#24); Flutter 3.47 Android build (#23) | Backend from prod-readiness (#20) or later: migration runner, `20260928_speaking_loop_completed_event_type`, auth rate limits, scrypt passwords |
| 1.3.0–1.3.1 | 2026-09-28 | Sudoku game (#21), production hardening (#20), Gradle fixes (#22) | Same as 1.3.2 |

## Unreleased — Codebase Consistency Pass

- `POST /v1/learning/cards` now rejects unsupported `card_mode` values with
  `400 { "error": "bad_request" }`; `new` remains the only supported mode.
- Mobile app credential nonces are now high-entropy random values instead of
  timestamp-derived strings.
- Mobile recent-word bootstrap now sends only `limit` and `target_language`.
  Learner-specific refill and duplicate avoidance use `POST /v1/learning/cards`
  plus `PUT /v1/user-word-cache`.
- Local ObjectBox batch writes now enforce the 1000-word cap after every
  `LocalDatabase.addBatch()` call.
- New-word telemetry now distinguishes local cache hits, backend refill hits,
  empty refills, and backend-error fallback behavior.
- PostgreSQL proficiency rows now use explicit anonymous `(device_id, language)`
  and signed-in `(user_id, language)` ownership indexes.

## Unreleased — ObjectBox Storage Migration

### Breaking Change: Local Data Reset on Upgrade

This release replaces SQLite with [ObjectBox](https://objectbox.io/) as the mobile local persistence layer.

**Impact:** All local vocabulary and study history is lost on upgrade. No migration from SQLite data is performed.

**Why:** The SQLite schema was removed completely and replaced with typed ObjectBox entities. Migrating legacy SQLite data is not supported.

**What users should expect:**
- On first launch after upgrade, the local word cache is empty.
- Previously recorded study history (swipe ratings) is cleared.
- The app will request a new word from the backend immediately.
- Study progress synced to the backend before upgrade is unaffected.

### Developer Notes

- ObjectBox entities are defined in `mobile/lib/src/data/local_database_entities.dart`.
- After modifying entities, regenerate bindings:
  ```
  cd mobile
  flutter pub run build_runner build --delete-conflicting-outputs
  ```
- For running tests on Linux, place the native library at `mobile/lib/libobjectbox.so`.
  Download from: https://github.com/objectbox/objectbox-c/releases/download/v4.3.1/objectbox-linux-x64.tar.gz
  Extract and copy `lib/libobjectbox.so` into `mobile/lib/`.
