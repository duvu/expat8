# Release Notes and Handoff: Language-Native Proficiency Scales

Date: 2026-05-06
Change: support-language-native-proficiency-scales

## Summary

This release introduces scale-native proficiency handling across backend and mobile:

- English uses CEFR (`A1` to `C2`).
- Chinese uses HSK (`HSK1` to `HSK6`).
- Proficiency contract is now `scale`, `level`, `level_index`.

## Backend highlights

- Added language profile primitives and scale-aware progression/fallback.
- Added additive compatibility aliases for transition window:
  - `proficiency_scale`, `proficiency_level`, `proficiency_level_index`
- Added configuration toggle:
  - `PROFICIENCY_COMPATIBILITY_MODE=additive|strict`
- Added telemetry fields in request/study/proficiency flows:
  - `target_language`, `proficiency_scale`, `proficiency_level`
- Added persistence support and backfill for `user_proficiency.scale` and `user_proficiency.level_index`.

## Mobile highlights

- `ProficiencyState` now includes `scale` and `levelIndex`.
- Session flow routes proficiency/new-word/rating actions by active language context.
- Badge rendering is scale-native (CEFR for English, HSK for Chinese).
- Added telemetry metadata on session/rating events with `target_language`, `scale`, and `level`.

## Verification

Executed and passing:

- Backend targeted tests (`config`, `api`, `postgres_word_store`)
- Backend integration set for scale behavior (`proficiency`, `generation_service`, `litellm_client`, `word_store`, `postgres_word_store`)
- E2E smoke coverage expanded:
  - English CEFR progression
  - Chinese HSK progression
  - cross-language isolation for same device

Note:

- Flutter test execution was unavailable in this environment because `flutter` was not installed in PATH.

## Operational checklist

1. Deploy backend with `PROFICIENCY_COMPATIBILITY_MODE=additive`.
2. Validate telemetry and dashboards by language + scale.
3. Roll out mobile version consuming `scale` + `level_index`.
4. When stable, switch backend to `PROFICIENCY_COMPATIBILITY_MODE=strict`.

## Risk watch

- Unexpected scale/level combinations by language.
- Sudden increase in invalid rating or invalid difficulty rejection rate.
- Changes in proficiency transition distribution by language.
