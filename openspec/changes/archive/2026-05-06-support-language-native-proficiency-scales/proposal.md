## Why

The current proficiency flow is CEFR-centric and does not model language-native scales end to end. We need a durable multi-language contract so English can use CEFR while Chinese uses HSK across generation, selection, study events, persistence, and mobile rendering.

## What Changes

- Introduce a language-native proficiency contract using `scale` + `level` (+ stable ordering index) instead of level-only semantics.
- Add a new capability for language profile driven proficiency behavior, including per-language progression and fallback rules.
- Extend backend word-feed and study-event behavior to resolve and apply proficiency within the active language scale.
- Extend vocabulary generation requirements so Chinese output uses HSK-aligned difficulty and language-specific pronunciation expectations.
- Update mobile learning-session requirements to parse, persist, and render proficiency using language-native scales.
- Extend persistence requirements to store and query proficiency scale metadata per user/device/language.

## Capabilities

### New Capabilities
- `language-native-proficiency-scales`: Define and enforce per-language proficiency scales (initially CEFR for English and HSK for Chinese) across backend and mobile contracts.

### Modified Capabilities
- `backend-word-feed-sync`: Word selection and study-event responses must apply proficiency within the requested language scale.
- `ai-vocabulary-generation`: Generation requirements must support language-specific difficulty scale and pronunciation schema for Chinese.
- `backend-postgres-persistence`: Persistence requirements must represent proficiency with scale-aware fields and constraints.
- `mobile-learning-session`: Mobile state and UI requirements must use language-native proficiency semantics.

## Impact

- Backend: `backend/src/proficiency.js`, `backend/src/app.js`, `backend/src/generation_service.js`, `backend/src/litellm_client.js`, validators, store layers, and database schema/migrations.
- Mobile: API client models, learning session controller/state, and proficiency display behavior.
- Contracts: API response/request payloads for proficiency and study events.
- Testing: update backend unit/integration coverage and mobile tests for language switching and scale-specific progression behavior.
