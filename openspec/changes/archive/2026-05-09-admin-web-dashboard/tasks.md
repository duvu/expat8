## 1. Project Setup

- [x] 1.1 Create the `web-admin/` application scaffold and basic route structure
- [x] 1.2 Add a shared API client layer for backend requests and auth headers
- [x] 1.3 Add environment/config wiring for backend base URL and admin token handling
- [x] 1.4 Add a responsive styling system and semantic dashboard shell

## 2. Article Workflow UI

- [x] 2.1 Build the article composer form for title, language, raw text, source URL, and visibility
- [x] 2.2 Build the article list view with filtering and processing state badges
- [x] 2.3 Build the article detail view for status, processing error, and publish/reprocess actions

## 3. Vocabulary Review UI

- [x] 3.1 Build the pending vocabulary review table with term, meaning, usage, and status columns
- [x] 3.2 Add approve, reject, and review-note actions for vocabulary items
- [x] 3.3 Surface validation and empty/loading/error states for the review queue

## 4. Auth, State, and Verification

- [x] 4.1 Wire dashboard requests to the existing app credential and admin token model
- [x] 4.2 Verify the dashboard reflects backend state transitions without duplicating pipeline logic
- [x] 4.3 Add smoke-test coverage or manual verification notes for article upload and vocabulary review flows
