## Context

The backend and mobile flows already carry language identifiers, but proficiency logic and validation are CEFR-centric in practice. Chinese onboarding requires HSK-native behavior, and the current model creates drift when language-specific concerns (scale, ordering, prompts, pronunciation fields) are forced into a CEFR-only path.

This change is cross-cutting: backend API contracts, persistence, vocabulary generation constraints, progression/fallback rules, and mobile state/UI all need to agree on a single proficiency contract.

## Goals / Non-Goals

**Goals:**
- Define one shared proficiency contract for all surfaces using `scale`, `level`, and deterministic ordering.
- Enforce language-profile based behavior where English uses CEFR and Chinese uses HSK.
- Ensure progression/fallback logic runs only within the active scale.
- Ensure mobile displays and persists scale-native proficiency without local assumptions.
- Keep backward compatibility manageable during rollout with additive API changes and clear migration sequencing.

**Non-Goals:**
- Introducing additional language scales beyond CEFR and HSK in this change.
- Redesigning the whole learning algorithm beyond adapting it to scale-aware progression.
- Fully solving linguistic quality for every language (this change defines contract + guardrails; content quality iteration continues separately).

## Decisions

1. Decision: Introduce a language profile registry as the source of truth.
- Choice: A central profile map defines scale id, ordered levels, normalization rules, and validation hooks per language.
- Rationale: Prevents CEFR hardcoding from spreading across API/store/mobile and enables deterministic behavior per language.
- Alternative considered: Keep CEFR internals and map HSK at boundaries.
- Why not: Creates long-term semantic drift and repeated bidirectional mapping bugs.

2. Decision: Proficiency contract is `(scale, level, level_index)`.
- Choice: API and store represent proficiency as scale id plus symbolic level and stable index.
- Rationale: Symbolic labels are human-readable; index enables efficient progression and fallback operations.
- Alternative considered: level string only.
- Why not: Requires repeated parsing and risks invalid cross-scale comparisons.

3. Decision: Progression/fallback engine is scale-scoped.
- Choice: Increment/decrement and fallback order are computed from the active profile list only.
- Rationale: Prevents accidental comparisons such as `A2` vs `HSK3` and keeps logic language-correct.
- Alternative considered: global mixed ordering table.
- Why not: Hard to maintain and semantically invalid across different scales.

4. Decision: API evolution is additive-first.
- Choice: Extend proficiency payloads with `scale` and `level_index` while retaining existing fields during migration.
- Rationale: Reduces risk for mobile/backend version skew and allows phased rollout.
- Alternative considered: immediate breaking payload replacement.
- Why not: High deployment risk and larger coordination burden.

5. Decision: Chinese generation/validation use HSK-native requirements.
- Choice: Prompt and validator rules are profile-aware; Chinese uses HSK-aligned difficulty and pinyin-priority pronunciation checks.
- Rationale: Improves learning relevance and avoids forcing English-centric assumptions.
- Alternative considered: keep one universal prompt schema.
- Why not: Produces weaker data quality for Chinese.

6. Decision: Persist scale metadata in proficiency records.
- Choice: Add scale-aware representation to persisted proficiency state and query paths.
- Rationale: Backend must be able to reconstruct correctness independent of client assumptions.
- Alternative considered: infer scale from language at read-time only.
- Why not: fragile for historical data, harder audits, and poor forward compatibility.

## Risks / Trade-offs

- [Risk] API compatibility drift between older mobile builds and new backend payloads. -> Mitigation: additive fields first, compatibility window, integration tests for mixed versions.
- [Risk] Existing CEFR-based tests may pass while HSK behavior regresses. -> Mitigation: add dedicated HSK progression/fallback test matrix and language-switch scenarios.
- [Risk] Data migration errors when backfilling scale metadata. -> Mitigation: idempotent migration scripts, dry-run validation, rollback plan.
- [Risk] More complex validator/prompt branching by language profile. -> Mitigation: strict profile interfaces and shared validation harness.
- [Risk] Increased operational complexity in telemetry dimensions. -> Mitigation: standard log schema including `target_language`, `scale`, `level` and dashboard presets.

## Migration Plan

1. Add language profile primitives and scale-aware helpers behind feature flags.
2. Extend backend responses with `scale` and `level_index` while keeping legacy-compatible fields.
3. Persist scale metadata in proficiency records and backfill existing rows based on language.
4. Update generation and validation paths to use profile-specific rules for Chinese.
5. Update mobile models/parsers/UI to consume and render scale-native proficiency.
6. Enable scale-native progression/fallback in production, monitor telemetry by language.
7. Remove CEFR-only assumptions after compatibility window and verification.

Rollback strategy:
- Keep legacy CEFR-only behavior togglable during rollout.
- If regression appears, disable scale-native progression path and continue serving legacy fields.
- Preserve additive payload fields so rollback does not require immediate mobile hotfix.

## Open Questions

- Should Chinese start at HSK1 for all users, or use a placement step later?
- Do we lock Chinese to Simplified script in MVP, or allow script variant selection immediately?
- Should `level_index` be 0-based or 1-based in public API contracts?
- What is the deprecation timeline for any legacy CEFR-only assumptions in mobile UI strings?
