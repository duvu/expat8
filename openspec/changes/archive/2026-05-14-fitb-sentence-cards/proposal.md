## Why

Passive word-card review builds recognition but not recall. Adding fill-in-the-blank (FITB) sentence cards to the review phase requires learners to actively produce the target word in context, improving retention without changing the gesture-only paradigm or adding new backend round-trips.

## What Changes

- New `FitbCard` Flutter widget renders the example sentence with the key word blanked; tap anywhere reveals the word + Vietnamese hint.
- `LearningSessionController` gains a `canFitb()` guard and applies FITB to ~50% of total learning sessions (random < 0.59 on review cards only).
- New `blank_word` column added to the `words` table; LLM generation prompt updated to populate it for `phrase` and `idiom` entries; `word` entries blank the entire `term`.
- `toApiWord()` extended to include `blank_word` in card API responses.
- No new API endpoints; no changes to session flow, SRS scoring, or gesture controls.

## Capabilities

### New Capabilities
- `fitb-sentence-card`: Mobile `FitbCard` widget, `canFitb()` guard logic, blank-and-reveal interaction model

### Modified Capabilities
- `mobile-learning-session`: Review cards may now be rendered as FITB at a ~50% rate (random < 0.59 threshold)
- `ai-vocabulary-generation`: LLM generation prompt must output `blank_word` for phrase/idiom vocabulary entries
- `learning-cards-api`: `toApiWord()` response shape gains optional `blank_word` field
- `backend-postgres-persistence`: New migration adds `blank_word TEXT` column to `words` table

## Impact

- **Mobile**: new `fitb_card.dart` widget + `LearningSessionController` changes; no new screens or routes
- **Backend DB**: one migration (`blank_word TEXT` nullable column on `words`)
- **Backend API**: `word_store.js` / `postgres_word_store.js` — `toApiWord()` gains one field
- **Backend worker**: LLM prompt template updated; existing words lacking `blank_word` are handled gracefully (null → skip FITB)
- **No breaking changes**: `blank_word` is additive; mobile ignores null gracefully; exam flow unaffected
