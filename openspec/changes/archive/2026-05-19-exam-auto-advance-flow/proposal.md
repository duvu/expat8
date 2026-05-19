## Why

The current exam flow forces users to pick a topic and tap a Next button between questions, which makes the experience slower and more fragmented than the rest of the app. We want a direct language-scoped exam that advances on answer selection and shows results as soon as the final answer is committed.

## What Changes

- Remove topic-based exam entry from the mobile flow and start exams directly from the active learning language.
- Advance to the next question automatically when the user taps an answer.
- Submit the session automatically after the final answer and transition to results without a Next button.
- Update backend exam session generation to build questions from the user's studied words in the chosen language instead of a selected topic.
- Update exam payloads, models, and contract docs to match the language-scoped flow.
- **BREAKING**: exam start and result payloads no longer depend on a user-selected topic.

## Capabilities

### New Capabilities
- `vocabulary-exam-flow`: language-scoped exam start, tap-to-advance question progression, and immediate result handoff after the final answer.

### Modified Capabilities
- _None_

## Impact

- `mobile/lib/src/exam/*`
- `mobile/lib/src/ui/learning_screen.dart`
- `backend/src/routes/exam.js`
- `backend/src/word_store.js`
- `backend/src/postgres_word_store.js`
- `contracts/api.md`
- mobile and backend exam tests
