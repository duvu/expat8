# Release Notes

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
