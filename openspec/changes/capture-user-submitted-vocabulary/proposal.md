## Why

Today the mobile app can only teach words that already exist in the backend vocabulary inventory. When a learner encounters an unfamiliar word while reading outside the app, there is no direct way to capture that high-intent word and bring it into the normal learning flow. We need a consistent cross-project path so user-entered words are stored, AI-enriched, and then learned through the same backend/mobile pipeline as the rest of the vocabulary system.

## What Changes

- Add a mobile word-capture flow where the learner can type a new word, submit it, and see whether it is pending enrichment, ready to study, or rejected as duplicate/invalid.
- Add a backend API and persistence model for user-submitted vocabulary requests, including user/device ownership, language, submission status, and optional link to the final stored word.
- Add asynchronous AI enrichment for submitted words so the worker produces the same vocabulary fields required by the learning card (`meaning_vi`, IPA, pronunciation, example, example translation, difficulty, topics, explanation, etc.).
- Make successfully processed submitted words join the normal persisted vocabulary inventory and become eligible for the existing learning-card refill flow instead of introducing a separate study path.
- Update current contracts, tests, and documentation so the new submission lifecycle is implemented consistently across mobile, backend, worker, and canonical API docs.

## Capabilities

### New Capabilities
- `mobile-word-capture`: Mobile UI, validation, local submission state, and learner-facing status for manually entered vocabulary terms.
- `user-submitted-vocabulary`: Backend API, persistence, asynchronous AI enrichment, duplicate handling, and promotion of processed user-submitted words into the standard learning inventory.

### Modified Capabilities
- `project-consistency-governance`: The new submission API fields and lifecycle must be documented and covered consistently across contracts, code, tests, and current docs.

## Impact

- **Mobile app**: `LearningScreen` / drawer navigation, repository/API client, local persistence for pending submissions, and learner-facing status UI.
- **Backend**: new submission endpoint(s), store methods, DB schema + migration, worker processing path, duplicate detection, and integration with the existing word persistence model.
- **AI enrichment**: a dedicated generation path for single submitted terms that reuses the same validation and stored-word contract as existing vocabulary generation.
- **Contracts/docs/tests**: `contracts/api.md`, backend tests, mobile tests, and OpenSpec/docs updates for lifecycle consistency.
