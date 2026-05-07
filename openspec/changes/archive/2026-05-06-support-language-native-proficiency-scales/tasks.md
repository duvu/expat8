## 1. Contract and language profile foundation

- [x] 1.1 Define language profile registry for `en -> CEFR` and `zh -> HSK` with ordered levels
- [x] 1.2 Implement shared helpers for resolving `scale`, `level`, and `level_index` by target language
- [x] 1.3 Refactor progression and fallback helpers to run within active profile only
- [x] 1.4 Add unit tests for profile resolution, progression, decrement, and fallback for both CEFR and HSK

## 2. Backend API and domain logic updates

- [x] 2.1 Extend proficiency response contract to include `scale` and `level_index`
- [x] 2.2 Update proficiency lookup endpoint to return scale-native proficiency by language
- [x] 2.3 Update study-event sync/submit responses to return scale-native proficiency contract
- [x] 2.4 Update word selection logic to filter and fallback using active language profile scale
- [x] 2.5 Add backend tests for English CEFR and Chinese HSK behavior across lookup, selection, and study events

## 3. AI generation and validation updates

- [x] 3.1 Add language-profile aware generation prompt templates for English and Chinese
- [x] 3.2 Enforce scale-aware difficulty validation (`cefr` for English, `hsk` for Chinese)
- [x] 3.3 Add Chinese pronunciation validation requirements aligned with language profile
- [x] 3.4 Add tests for generation parsing and validation failures on invalid scale-specific difficulty values

## 4. Persistence and migration

- [x] 4.1 Add schema support for storing proficiency scale metadata (`scale`, `level_index`) per learner-language state
- [x] 4.2 Implement migration/backfill for existing proficiency rows based on language defaults
- [x] 4.3 Update persistence queries and upserts to read/write scale-native proficiency atomically
- [x] 4.4 Add integration tests for migration safety and identity-language isolation

## 5. Mobile model, state, and UI updates

- [x] 5.1 Extend mobile proficiency model to store `scale` and `level_index`
- [x] 5.2 Update API parsing for proficiency and study-event responses with new fields
- [x] 5.3 Update learning session state to keep proficiency context per active language
- [x] 5.4 Update proficiency badge rendering to show CEFR labels for English and HSK labels for Chinese
- [x] 5.5 Add mobile tests for language switching and scale-specific label rendering

## 6. Compatibility rollout and observability

- [x] 6.1 Implement additive API compatibility path for older clients during transition window
- [x] 6.2 Add telemetry fields `target_language`, `scale`, and `level` to backend and mobile logs
- [x] 6.3 Create dashboards/alerts for proficiency distribution and unexpected scale-level transitions
- [x] 6.4 Document rollout, rollback toggles, and deprecation timeline for CEFR-only assumptions

## 7. End-to-end verification and release readiness

- [x] 7.1 Run end-to-end flow test for English learning with CEFR progression
- [x] 7.2 Run end-to-end flow test for Chinese learning with HSK progression
- [x] 7.3 Verify no cross-language contamination of proficiency state for the same identity
- [x] 7.4 Prepare release notes and implementation handoff for opsx-apply
