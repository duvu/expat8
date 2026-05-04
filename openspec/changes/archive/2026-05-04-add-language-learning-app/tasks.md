## 1. Project Setup

- [x] 1.1 Scaffold the Flutter mobile app structure for Android and iOS
- [x] 1.2 Scaffold the backend service structure and development configuration
- [x] 1.3 Add shared API contract documentation or DTO definitions for mobile-backend payloads
- [x] 1.4 Add environment configuration for backend base URL, LiteLLM model settings, and request timeouts

## 2. Mobile Local Data Layer

- [x] 2.1 Add local persistence dependencies and database initialization
- [x] 2.2 Implement local word storage with required vocabulary card fields and learning metadata
- [x] 2.3 Implement local study event storage with `client_event_id` and sync status
- [x] 2.4 Implement sync queue storage with retry count and next retry timestamp
- [x] 2.5 Implement local pruning that retains only the 1000 most recent words
- [x] 2.6 Add tests for local word persistence, study event persistence, and 1000-word pruning behavior

## 3. Mobile Learning Session

- [x] 3.1 Implement the vocabulary card UI with term, meaning, Vietnamese-friendly pronunciation, IPA, example, and translated example
- [x] 3.2 Implement downward swipe handling to request and display the next card
- [x] 3.3 Implement session card selection targeting 3 new cards and 7 review cards per 10-card window
- [x] 3.4 Implement fallback from unavailable card type to the other available card type
- [x] 3.5 Implement rating controls for not remembered, hard, remembered, and too easy
- [x] 3.6 Implement local review scheduling updates after each rating
- [x] 3.7 Add mobile tests for swipe navigation, card rendering, selection ratio, fallback, and rating updates

## 4. Mobile API Client and Sync

- [x] 4.1 Implement backend API client for new-word feed with a 5-second mobile timeout
- [x] 4.2 Implement local fallback when new-word feed fails, times out, or the device is offline
- [x] 4.3 Implement recent-word bootstrap client for restoring up to 1000 words
- [x] 4.4 Implement study-event sync client
- [x] 4.5 Implement background sync worker with retry behavior
- [x] 4.6 Add tests for timeout fallback, offline fallback, sync success, sync failure, and duplicate-safe retry behavior

## 5. Backend Data Model

- [x] 5.1 Add server database schema for vocabulary words
- [x] 5.2 Add server database schema for append-only study events with unique `client_event_id`
- [x] 5.3 Add server database schema for future user word state using nullable `user_id` and device-based association
- [x] 5.4 Add indexes for normalized term deduplication, recent-word lookup, and study-event idempotency
- [x] 5.5 Add tests for database constraints and idempotent event persistence

## 6. Backend APIs

- [x] 6.1 Implement new-word feed endpoint with source language, target language, mode, and limit parameters
- [x] 6.2 Implement recent-word bootstrap endpoint capped at 1000 returned words
- [x] 6.3 Implement study-event sync endpoint with accepted and rejected event reporting
- [x] 6.4 Implement device-based event association while keeping `user_id` nullable
- [x] 6.5 Add API tests for successful feed, recent bootstrap, event sync, and duplicate event retry

## 7. AI Vocabulary Generation

- [x] 7.1 Add LiteLLM integration behind a backend generation service interface
- [x] 7.2 Implement structured JSON prompt and response parsing for generated vocabulary
- [x] 7.3 Implement validation for required fields, non-empty IPA, related example, and content suitability
- [x] 7.4 Implement deduplication by language and normalized term
- [x] 7.5 Persist accepted generated words with generation source metadata
- [x] 7.6 Add tests for valid generation, invalid JSON rejection, missing field rejection, duplicate rejection, and stored inventory reuse

## 8. Observability and Quality

- [x] 8.1 Add telemetry events for card shown, backend success, backend timeout, local fallback, rating submitted, sync success, sync failure, and cache pruning
- [x] 8.2 Add logging for AI generation failures without exposing sensitive user data
- [x] 8.3 Add end-to-end smoke test covering new word retrieval, local save, rating, sync queue, and backend sync
- [x] 8.4 Document MVP configuration, local development setup, and known limitations
