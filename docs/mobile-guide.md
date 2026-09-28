# Mobile Guide

The mobile app lives in `mobile/`. It is a Flutter app using ObjectBox for local persistence and compile-time `--dart-define` values for backend/app credential configuration.

## Commands

```bash
cd mobile
flutter pub get
flutter test
flutter test test/learning_session_controller_test.dart
flutter pub run build_runner build --delete-conflicting-outputs
```

Linux desktop/unit-test runs that touch ObjectBox require `mobile/lib/libobjectbox.so`.

## Runtime Configuration

Local run example:

```bash
cd mobile
flutter run \
  --dart-define=BACKEND_BASE_URL=http://localhost:8787 \
  --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET>
```

Important compile-time values:

- `BACKEND_BASE_URL` — backend base URL.
- `APP_CREDENTIAL_APP_ID` — app credential id used for HMAC signing.
- `APP_CREDENTIAL_SECRET` — app credential secret used for HMAC signing.
- `NEW_WORD_TIMEOUT_SECONDS` — timeout/product behavior mirrored with backend.
- `APP_LOG_LEVEL` — app logging level for release/debug behavior.

Changing any compile-time value requires a fresh app rebuild.

## Local-First Responsibilities

Mobile stores the learner-facing working set locally so learning can continue offline:

- Vocabulary cards and bundled seed vocabulary.
- Study events and sync queue entries.
- Settings, device id, and user/session state.
- Local diagnostic logs.
- User-submitted words while offline or pending sync.

Backend remains the source of truth. Mobile syncs study events and inventory state when network access is available.

## Backend Requests

- All `/v1/*` requests are signed with app credential headers.
- Signed-in requests include `Authorization: Bearer <session_token>`.
- Anonymous requests use the persisted device id.
- The same device id is preserved after sign-in so offline/cache context remains stable.

## Card Loading

Mobile uses `POST /v1/learning/cards` with `card_mode: "new"` for backend-selected batches.

Important constraints:

- Do not send `exclude_server_word_ids`, `current_word_id`, or other exclusion fields.
- Duplicate avoidance belongs to backend learner state and `PUT /v1/user-word-cache`.
- `card_mode` must be `"new"` or omitted.

## User-Submitted Vocabulary

The app exposes an add-word flow for learner-entered words or short expressions:

1. Store the submission locally.
2. Sync through `POST /v1/user-submitted-words`.
3. Poll/refresh through `GET /v1/user-submitted-words`.
4. Track lifecycle values `queued`, `processing`, `ready`, and `failed`.
5. Insert resolved ready words into normal local vocabulary inventory.

## Speaking Foundation

The v1 speaking feature is local record/playback/self-rating. It syncs behavioral speaking events and summary data, but does not upload pronunciation audio for server-side scoring.

## Offline Mode

Every feature opens without a network connection; data is cached in ObjectBox and writes are queued, then synced when the backend is reachable again.

| Feature | Offline behavior |
|---|---|
| Vocabulary cards, sentences, speaking drill, history, stats | Fully local; ratings/speaking events queued |
| Proficiency level | Last known level per language cached (`proficiency.cache.<lang>` setting) |
| Add word | Saved as `queuedSync`, sent automatically when online; 4xx from the server marks it failed |
| Memorization | Passage list, segments and progress served from cache; drill progress synced with the other queues |
| Articles | List, article and vocabulary cached per account; creating an article needs a connection |
| Video shadowing | Library and transcripts cached (transcripts prefetched after a library refresh); video playback itself needs internet |
| Weekly speaking summary | Computed from this device's attempts when the backend is unreachable |
| Exam | Starting needs a connection (answers are server-side); submitted answers are saved and scored when back online |
| Games | Fully local |

Sync (`WordRepository.syncPendingEvents` + memorization progress) runs at startup, every 3 minutes, on app resume, when connectivity returns (`ConnectivityMonitor`, `connectivity_plus`) and right after sign-in/registration. Runs never overlap. Network, auth, rate-limit and 5xx failures stay queued with backoff; permanent rejections (400/404/409/410/413/422) are dropped and the event is marked failed. On sign-in the backend attaches the device's anonymous study/speaking history and proficiency to the account (see `contracts/api.md`).

An `OfflineBanner` is shown above every screen while the device has no connection.

## Games (offline)

`lib/src/games/` holds offline mini-games, opened from the drawer's **Games** item for every user (no sign-in, no network). `GamesHubScreen` lists them; add new games there.

Sudoku (`lib/src/games/sudoku/`):

- `SudokuGenerator` builds puzzles on-device (run in an isolate via `compute`), always with a unique solution. Five levels (`SudokuDifficulty`): Beginner 45, Easy 38, Medium 32, Hard 28, Expert 24 target givens.
- `SudokuGameController` handles input, notes, undo, hints, mistakes and the timer, and auto-saves the unfinished game so it can be continued after the app restarts.
- `SudokuChampionStore` keeps the top 10 solves per level (ranked by time + 30s per hint, then mistakes), play stats and the player name.
- All game data lives in the ObjectBox settings table through `LocalDatabaseGameStorage` (keys prefixed `games.`); nothing is sent to the backend.

`test/offline_mode_test.dart` checks that learning (bundled vocabulary, studying, rating, queued sync) works with the backend unreachable.

## Android Release Builds

Use the same current production define set for APK and AAB builds. Source real values from a local env file or secret manager; never commit them.

```bash
cd mobile
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --release \
  --dart-define=BACKEND_BASE_URL=https://expat8.x51.vn \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET> \
  --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
  --dart-define=APP_LOG_LEVEL=info
```

Outputs:

- APK: `build/app/outputs/flutter-apk/app-release.apk`.
- AAB: `build/app/outputs/bundle/release/app-release.aab`.

Android emulator networking cannot reach LAN/VPN IPs such as `10.x.x.x`; use a public backend URL for emulator builds. LAN URLs are only suitable for physical devices on the same network.
