## Why

We need a mobile-first language learning app that lets Vietnamese learners study vocabulary in short sessions with a simple swipe-down interaction. The app must remain usable when the backend is slow or offline, while still building a long-term server-side vocabulary and learning history foundation for future personalization.

## What Changes

- Add a Flutter mobile learning experience for Android and iOS where swiping down advances to the next vocabulary card.
- Add vocabulary cards that show the term, Vietnamese meaning, Vietnamese-friendly pronunciation, IPA, usage example, and Vietnamese translation.
- Add a session selection policy that targets 3 new words and 7 review words per 10-card learning cycle.
- Add local-first storage on mobile with a hard cap of 1000 most recent words.
- Add backend fallback behavior: new-word requests use a 5-second timeout, then fall back to local words when the backend fails, times out, or the device is offline.
- Add append-only study events and background sync from mobile to backend.
- Add backend APIs for new-word feed, recent-word bootstrap, and study-event sync.
- Add backend AI vocabulary generation through LiteLLM, including schema validation, deduplication, and persistence.
- Prepare the data model for future authentication by using a stable device identifier now and nullable user identifiers later.

## Capabilities

### New Capabilities

- `mobile-learning-session`: Flutter learning session, swipe-down navigation, card display, new/review selection ratio, and review scheduling.
- `mobile-local-cache-sync`: mobile local database, 1000-word retention policy, offline fallback, study-event queue, and sync behavior.
- `backend-word-feed-sync`: backend vocabulary feed, recent-word bootstrap, study-event sync APIs, and server persistence model.
- `ai-vocabulary-generation`: LiteLLM-based vocabulary generation, structured output validation, deduplication, and database storage.

### Modified Capabilities

None.

## Impact

- Adds a new Flutter mobile app surface for Android and iOS.
- Adds mobile local persistence, likely SQLite with Drift or an equivalent structured local database.
- Adds backend REST APIs for vocabulary feed and study event sync.
- Adds server database tables for words, study events, and future user word states.
- Adds LiteLLM as the abstraction layer for AI model calls.
- Adds offline-first and retry behavior that affects API client, repository, and sync worker design.
- Defers authentication, payments, speech scoring, social learning, and full admin tooling from the initial scope.
