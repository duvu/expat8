# Language-Native Proficiency Rollout (CEFR + HSK)

Date: 2026-05-06
Status: implementation guidance for rollout, observability, and deprecation

## 1. Compatibility strategy

During migration, backend responses run in additive compatibility mode by default:

- Keep canonical proficiency fields: `scale`, `level`, `level_index`.
- Add compatibility aliases for older clients:
  - `proficiency_scale`
  - `proficiency_level`
  - `proficiency_level_index`

Configuration:

- `PROFICIENCY_COMPATIBILITY_MODE=additive` (default)
- `PROFICIENCY_COMPATIBILITY_MODE=strict` (disable aliases after transition)

This keeps newer clients scale-native while older clients continue reading stable level fields.

## 2. Rollout plan

1. Deploy backend with `PROFICIENCY_COMPATIBILITY_MODE=additive`.
2. Verify logs include `target_language`, `proficiency_scale`, `proficiency_level`.
3. Ship mobile clients that consume scale-native fields (`scale`, `level`, `level_index`).
4. Monitor old/new client mix and proficiency distribution by language.
5. After adoption threshold, switch backend to `PROFICIENCY_COMPATIBILITY_MODE=strict`.

## 3. Rollback toggles

If regression appears in production:

- Toggle backend back to `PROFICIENCY_COMPATIBILITY_MODE=additive`.
- Keep scale-native progression enabled (data model remains backward-safe).
- If required, temporarily route problematic clients to English default while preserving language-isolated proficiency rows.

## 4. Observability requirements

Backend logs (minimum fields):

- `target_language`
- `proficiency_scale`
- `proficiency_level`
- `proficiency_level_index` (when available)

Mobile logs/telemetry (minimum fields):

- `target_language`
- `scale`
- `level`

## 5. Dashboard and alert recommendations

Dashboard widgets:

- Proficiency distribution by `target_language` and `proficiency_scale`.
- Progression transitions per level pair (`A1->A2`, `HSK2->HSK3`, etc.).
- Invalid rating / validation rejection rate by language.

Alerts:

- Unexpected scale-level combinations (for example `target_language=zh` with `proficiency_scale=cefr`).
- Sudden spike of progression regressions (`hard`-driven drops) for one language.
- Study-event accept rate drop or idempotency anomaly by language.

## 6. Deprecation timeline (recommended)

- Week 0: deploy additive mode + telemetry.
- Week 1-2: monitor compatibility aliases usage.
- Week 3: freeze new CEFR-only assumptions in mobile/backend.
- Week 4: move to strict mode if metrics are stable.

## 7. Exit criteria

- No cross-language proficiency contamination in smoke/e2e checks.
- Stable progression behavior for both English (CEFR) and Chinese (HSK).
- Compatibility alias usage below agreed threshold.
- Release notes and operator handoff completed.
