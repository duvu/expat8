# Active Change Audit

Date: 2026-05-06

This audit documents why completed OpenSpec changes are left active in this
implementation pass instead of being archived automatically.

## Completed Changes Still Active

- `gesture-only-learning-and-daily-topup` — 29/29 tasks complete.
- `word-feed-batch-loading` — 19/19 tasks complete.
- `unify-learning-cards-backend-state` — 30/30 tasks complete.
- `add-backend-error-tracing-logger` — 12/12 tasks complete.
- `backend-managed-vocabulary-pool-selection` — 70/70 tasks complete.
- `fix-auth-cors-register-hardening` — 28/28 tasks complete.
- `fix-mobile-auth-feedback-and-swipe-state` — 38/38 tasks complete.
- `add-user-identity-swipe-navigation` — 44/44 tasks complete.

## Why Not Archived Here

Archiving mutates canonical specs and can merge or rewrite capability
requirements across several overlapping changes. This consistency pass focused
on code/contracts/docs drift and did not take ownership of those broader spec
merges. These completed changes should be archived in a dedicated OpenSpec
archive pass after the owner reviews generated spec deltas.

## Incomplete Changes Still Active

- `mobile-vocabulary-prefetch-refresh` — historical proposal is superseded by
  ObjectBox and backend-managed card selection; its artifacts now carry a
  current-state note.
- `add-adaptive-proficiency-system` — still has unfinished manual, review, and
  documentation tasks; `/v1/words/next` references are marked historical.
