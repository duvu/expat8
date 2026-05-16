# Release Notes: Beta Speaking Foundation (v9.9)

## Overview
This release introduces the **Speaking Foundation** feature—a foundational module enabling learners to practice speaking English through voice input, AI-powered evaluation, and integrated proficiency tracking. This is a **phase 0-3 beta rollout** with audio processing kept local to the device for enhanced privacy and offline-first architecture.

## What's New

### Core Features
- **Speaking Practice Module**: Users can record English phrases and receive immediate feedback on pronunciation, clarity, and grammar.
- **Local Audio Processing**: All audio remains on the device; only structured metadata (attempt metadata, ratings) is sent to the backend.
- **Integrated Proficiency Tracking**: Speaking attempts are tracked independently from rating events; proficiency levels are updated only through learning card ratings (too_easy/hard), not by speaking events.
- **Retry & Learning Loop**: Users can retry speaking attempts with incremental retry counters for analytics and learning progress.
- **Self-Evaluation**: Learners rate their own clarity (`self_rating_clear`), with options: `unclear`, `somewhat_clear`, `clear`.

### Backend Enhancements
- **Event Pipeline**: New event types `speaking_recorded` and `speaking_self_rated_clear` are accepted, validated, and stored independently.
- **Metadata-Only Payloads**: Speaking events contain only:
  - `attempt_id` (UUID)
  - `prompt_id` (reference to speaking prompt)
  - `duration_ms` (recording length)
  - `retry_count` (number of retries)
  - `self_rating` (clarity rating)
- **No Audio Storage**: Backend does not store, process, or expose audio files; audio remains device-local only.
- **Proficiency Isolation**: Speaking events do NOT trigger proficiency level changes. Proficiency is controlled exclusively through rating events on learning cards.

### Mobile Enhancements
- **Speaking UI Module**: New Flutter widgets for recording, playback, and feedback.
- **Feature Flag**: `SPEAKING_FOUNDATION_ENABLED` (default `true`) gates speaking UI visibility and can be toggled via build-time `--dart-define` if needed.
- **Record Permission**: App requests `RECORD_AUDIO` permission on first speaking attempt.
- **flutter_tts Integration**: Text-to-speech for prompt playback; requires Android SDK `compileSdk >= 36`.

## Technical Highlights

### Proficiency Model
- **Proficiency Update Rule**: Only `too_easy` (2 consecutive) or `hard` ratings trigger level changes.
- **Speaking Events Do Not Update Proficiency**: Validated by smoke test; speaking events are logged but proficiency remains unchanged.
- **Example**: A1 → A2 requires 2 consecutive `too_easy` ratings on learning cards, independent of any speaking activity.

### API Contract
All requests to `/v1/*` endpoints require app credentials:
- `X-Device-ID`: Unique device identifier
- `X-App-Version`: Mobile app version
- For authenticated routes: `Authorization: Bearer <session_token>`

New speaking event endpoints:
- `POST /v1/learning/events` (accepts `speaking_recorded`, `speaking_self_rated_clear` event types)

### Android Build Requirements
- **Kotlin Plugin**: 2.1.10 (required for flutter_tts 4.2.5 Kotlin 2.2.0 metadata compatibility)
- **compileSdk**: 36 (flutter_tts requirement)
- **minSdk**: 24
- **Permission**: RECORD_AUDIO (added to AndroidManifest.xml)

## Known Limitations (Phase 0-3)

1. **Device-Local Audio Only**: Audio files are not transmitted or stored on backend; all processing is on-device.
2. **No Real-Time Feedback Loop**: Feedback UI is designed for self-evaluation; backend AI evaluation is not yet integrated.
3. **No Audio Replay from Backend**: Users cannot replay their recording from another device; audio remains local-only.
4. **Speaking Does Not Affect Proficiency**: This is intentional for phase 0-3; proficiency is controlled by card rating events only.
5. **Feature Flag Requirement**: Speaking UI is opt-in via build flag; `--dart-define SPEAKING_FOUNDATION_ENABLED=false` disables it.

## Testing & Validation

### Smoke Test 9.8 (Backend)
- **Test Scenario**: 5 consecutive `too_easy` rating events + 2 speaking events (no audio payloads)
- **Result**: 7/7 events accepted; proficiency progressed A1 → A2 from rating events only; speaking events logged but proficiency unchanged.
- **Coverage**: Backend event validation, proficiency isolation, and independent event streams verified.

### Backend Test Suite
- **97/99 tests passing** (2 PostgreSQL integration tests skipped in in-memory mode)
- **No regressions detected** across event handling, user state, and proficiency logic.

### Mobile Build
- **Release APK**: Successfully built with Kotlin 2.1.10, compileSdk 36.
- **57 MB artifact**: `build/app/outputs/flutter-apk/app-release.apk`
- **Feature flag enabled**: `mobile/lib/src/config.dart` `SPEAKING_FOUNDATION_ENABLED` defaults `true`.

## Deployment Instructions

### Prerequisites
- **Backend**: Node.js 22+, PostgreSQL 15+ (or in-memory WordStore for dev)
- **Mobile**: Flutter 3.24+, Android SDK 36+, Kotlin 2.1.10

### Backend Deployment
```bash
cd backend
npm install
npm run migrate:up  # If using PostgreSQL
npm test            # Run all tests
npm start           # Start API server
npm run start:worker # (Optional) Start background worker
```

### Mobile Deployment
```bash
cd mobile
flutter pub get
flutter build apk --release \
  --dart-define BACKEND_BASE_URL=<YOUR_BACKEND_URL> \
  --dart-define SPEAKING_FOUNDATION_ENABLED=true
```

The built APK will be available at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Production Android Verification
- APK build command used:
  `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --release --dart-define=BACKEND_BASE_URL=https://expat8.x51.vn --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app --dart-define=APP_CREDENTIAL_SECRET=expat8-mobile-secret --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 --dart-define=APP_LOG_LEVEL=info`
- Smoke check: `adb -s emulator-5554 uninstall vn.x51.expat8 && adb -s emulator-5554 install /home/beou/IdeaProjects/expat8/mobile/build/app/outputs/flutter-apk/app-release.apk && adb -s emulator-5554 shell am start -W -n vn.x51.expat8/.MainActivity` completed successfully after removing the previous incompatible install.
- Matching release bundle command still produces `build/app/outputs/bundle/release/app-release.aab` with the same production defines.

## Release Timeline

| Phase | Duration | Features |
|-------|----------|----------|
| **0-3 (Current)** | Beta | Local audio, device-only processing, metadata-only backend payloads, no proficiency impact |
| **4** | TBD | Real-time backend AI evaluation (optional on user opt-in) |
| **5+** | TBD | Cross-device audio replay, analytics dashboard, leaderboards |

## Rollback Plan

If critical issues are discovered post-release:
1. **Disable Feature Flag**: Rebuild mobile with `--dart-define SPEAKING_FOUNDATION_ENABLED=false`
2. **Backend Compatibility**: All speaking events are non-blocking; they can be silently dropped or ignored if needed
3. **Data Retention**: Speaking event data is preserved; no migration required if feature is disabled

## Support & Feedback

- **Issues & Bugs**: Report to the development team with APK version and reproduction steps
- **Feature Requests**: Submit to product team with use-case details
- **Privacy Concerns**: Audio never leaves the device in phase 0-3; backend stores only metadata

---

**Release Date**: May 9, 2026
**Build Version**: 9.9 (Speaking Foundation Beta)
**Backend Version**: Latest (97 tests passing)
**Mobile APK Size**: 57 MB
**Kotlin Version**: 2.1.10
**Android SDK**: 36+
