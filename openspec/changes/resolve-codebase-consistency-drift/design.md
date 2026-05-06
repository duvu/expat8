## Context

The current repo has moved through several fast changes: mobile persistence was reset to ObjectBox, `/v1/words/next` was removed in favor of `POST /v1/learning/cards`, optional user sessions were layered onto app credentials, and prefetch/refill logic started moving toward backend-owned selection. The implementation has advanced faster than some OpenSpec artifacts and docs, so the same product surface is now described multiple ways.

The drift is visible in three places:

- Live code and `contracts/api.md` say mobile card loading is `POST /v1/learning/cards`, while active OpenSpec artifacts still describe `/v1/words/next`.
- Live mobile code uses ObjectBox, while setup docs and active prefetch design still mention SQLite/sqflite.
- Several API fields are present in one layer but ignored in another, such as `card_mode`, `source_language`, `device_id`, and `excludeIds`.

The stakeholders are backend and mobile developers, release/deploy operators, and future agents that use OpenSpec as the source of implementation context.

## Goals / Non-Goals

**Goals:**

- Make backend store implementations return the same response shape for study-event sync.
- Make card-loading and recent-word API parameters contract-backed and test-covered.
- Make mobile signing, local retention, and logging behavior match the contracts they imply.
- Make PostgreSQL user proficiency ownership explicit instead of encoded through synthetic device IDs.
- Reconcile OpenSpec and developer docs so current docs describe ObjectBox and `POST /v1/learning/cards`.
- Add guardrails that keep future cross-project changes synchronized.

**Non-Goals:**

- Reintroducing `/v1/words/next` or adding another card-loading endpoint.
- Redesigning adaptive proficiency scoring, CEFR progression, or card selection ratios.
- Adding a new background execution framework for mobile refresh.
- Migrating legacy SQLite data into ObjectBox.
- Rewriting historical investigation docs beyond adding clear historical labels.

## Decisions

### D1: Treat `POST /v1/learning/cards` as the only card-loading path

All remote card refill behavior should stay on `POST /v1/learning/cards`. The change should not restore `/v1/words/next`, even if stale OpenSpec artifacts mention it. That route was intentionally removed by `unify-learning-cards-backend-state`.

Alternative considered: preserve `/v1/words/next` as a compatibility alias. That would keep duplicate avoidance split between client-provided exclusions and backend-owned state, which is the drift this change is trying to remove.

### D2: Keep `card_mode: "new"` explicit, but reject unsupported modes

The current mobile client already sends `card_mode: "new"` and the contract documents it. Keeping the field avoids unnecessary churn and leaves room for future modes, but the backend must reject any value other than `new` until additional modes are specified.

Alternative considered: remove `card_mode` from mobile and contract. That is simpler for this release, but it would require extra churn for no product gain and would erase an already documented extension point.

### D3: Scope `/v1/words/recent` to read-only bootstrap semantics

`/v1/words/recent` should accept only the parameters it actually needs for read-only bootstrap: `limit` and `target_language`. Duplicate avoidance, device context, and learner-specific claims belong to `/v1/learning/cards` and `/v1/user-word-cache`.

Alternative considered: add large `exclude_ids` support to `/v1/words/recent`. That would make long query strings part of the public contract and duplicate a responsibility already owned by backend claim/cache state.

### D4: Store response parity is enforced through shared tests

`WordStore` and `PostgresWordStore` should both use a `latestProficiency` style internal variable for sync results instead of mixing raw proficiency objects and record-study-event results. Regression tests should cover empty sync batches and all-rejected batches in both store layers.

Alternative considered: patch only the production PostgreSQL path. That leaves unit tests green while the in-memory contract remains misleading.

### D5: Local word retention is enforced inside `LocalDatabase`

The 1000-word cap should be enforced by `LocalDatabase.addBatch()` and related local persistence boundaries after every batch write. Callers such as `WordRepository`, startup prefetch, and refresh workers should not need to remember an additional prune call.

Alternative considered: add missing prune calls at every caller. That is fragile because the invariant can be broken by the next batch insert path.

### D6: User proficiency gets explicit PostgreSQL ownership

Signed-in user proficiency rows should be unique by `(user_id, language)` where `user_id IS NOT NULL`. Anonymous rows should remain unique by `(device_id, language)` where `user_id IS NULL`. The code should stop inserting `device_id = "user:<userId>"` for user profiles.

Alternative considered: keep the synthetic `device_id` convention. It avoids a migration now but makes future user/device merge behavior harder to reason about.

### D7: OpenSpec reconciliation is part of the change

This change should update stale active OpenSpec artifacts, archive completed changes where appropriate, and label historical dated docs. The goal is not just to fix code bugs; it is to restore the spec system as useful project memory.

Alternative considered: fix code only. That would leave future work likely to reintroduce the same old route/storage assumptions.

## Risks / Trade-offs

- [Risk] Rejecting unsupported `card_mode` values could break an unofficial client that previously sent arbitrary modes -> Mitigation: contract already lists only `new`; document the stricter validation and add tests.
- [Risk] Removing ignored mobile query params from `/v1/words/recent` may reveal assumptions in refresh code -> Mitigation: route refresh/top-up behavior through `/v1/learning/cards` and cache inventory where learner state matters.
- [Risk] Adding a user proficiency uniqueness migration can fail if existing data contains duplicate user-language rows -> Mitigation: add a cleanup migration that keeps the most recently updated row before creating the partial unique index.
- [Risk] OpenSpec reconciliation can be noisy because multiple completed changes are unarchived -> Mitigation: keep archive/supersede commits separate from behavior fixes where possible.
- [Risk] Historical docs remain searchable and can still confuse readers -> Mitigation: add a consistent header note to dated investigation docs that are not current source of truth.

## Migration Plan

1. Add backend and mobile regression tests for the inconsistent behaviors before changing implementation.
2. Fix backend store response shape, card-mode validation, and recent-word parameter handling.
3. Add PostgreSQL migration for explicit user proficiency uniqueness and update the store code to use `user_id` conflicts.
4. Update mobile nonce generation, local batch retention, recent-word/bootstrap client shape, and logging event taxonomy.
5. Update `contracts/api.md`, current setup docs, mobile README, and release notes.
6. Reconcile OpenSpec active changes by marking superseded `/v1/words/next` tasks/design notes and archiving completed changes when ready.
7. Run backend tests and mobile tests. Run OpenSpec status/validation for the new change.

Rollback is a coordinated code/docs revert. Database rollback should drop the new user-proficiency partial unique index only if the code is also reverted to the previous synthetic-device convention.

## Open Questions

- Should `/v1/words/recent` remain in mobile production code at all after backend-managed refill is fully standardized, or should it become a diagnostics/bootstrap-only utility?
- Should this change archive completed OpenSpec changes immediately, or only reconcile active artifacts and leave archive decisions to a separate cleanup pass?
