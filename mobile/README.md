# Expat8 Mobile App

Flutter client for Expat8 vocabulary learning.

## Adaptive Proficiency UX

- Proficiency badge is shown in the top-right of the learning screen.
- Rating actions are shown as one horizontal row with 4 equal-width buttons:
	- Easy
	- Too Easy
	- Hard
	- Too Hard
- Level-change feedback is surfaced in-app after backend confirms progression/regression.

## Startup Refresh

At startup, the app initializes a refresh worker and triggers:

- first-install prefetch (fire-and-forget)
- daily refresh check (fire-and-forget)

Startup flow keeps loading non-blocking and logs refresh failures without crashing.

## Build Defines

Key runtime defines:

- BACKEND_BASE_URL
- NEW_WORD_TIMEOUT_SECONDS
- APP_CREDENTIAL_APP_ID
- APP_CREDENTIAL_SECRET
- VOCAB_PREFETCH_LIMIT
- VOCAB_DAILY_REFRESH_COUNT
- VOCAB_PROACTIVE_THRESHOLD
- VOCAB_PROACTIVE_MIN_NEW

Example:

```bash
flutter run \
	--dart-define=BACKEND_BASE_URL=https://expat8.x51.vn \
	--dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
	--dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
	--dart-define=APP_CREDENTIAL_SECRET=expat8-mobile-secret
```
