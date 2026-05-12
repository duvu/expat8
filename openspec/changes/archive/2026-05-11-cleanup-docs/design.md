## Context

The live codebase has converged on ObjectBox mobile storage, signed `/v1/*` requests, and `POST /v1/learning/cards` as the card-refill endpoint. Several markdown documents still describe earlier states as if they are operational guidance: SQLite/sqflite storage, `/v1/words/next`, unsigned `/v1/*` curl examples, `GET /v1/learning/cards`, removed refresh/sync workers, and removed `prefetchBatch()` flows.

This cleanup intentionally treats current developer/search hygiene as more important than preserving every historical investigation note in the repo.

## Goals / Non-Goals

**Goals:**
- Remove markdown files whose main content contradicts current code.
- Update otherwise-current docs when only a small section is stale.
- Keep `contracts/api.md`, `README.md`, `mobile/README.md`, and `docs/mvp-setup.md` as the current source-of-truth entry points.
- Leave runtime code untouched.

**Non-Goals:**
- Reconstruct or rewrite large historical docs.
- Archive deleted documents elsewhere.
- Resolve behavioral drift in mobile prefetch/top-up code.

## Decisions

### D1: Delete stale historical docs instead of adding more caveats

Documents primarily about superseded implementations will be deleted. A historical note at the top is not enough when the body remains highly searchable and repeatedly states removed APIs or storage as "current".

Examples include docs centered on `/v1/words/next`, SQLite/sqflite, unsigned `/v1/*` curl examples, or removed mobile worker/prefetch flows.

Alternative considered: keep all docs with stronger historical labels. Rejected because the user explicitly asked to delete contradictory documentation and the repo already has current source-of-truth docs.

### D2: Patch small stale sections in current docs

Small contradictions inside otherwise-current docs should be edited rather than deleting the whole document. This applies to endpoint lists, setup notes, and security docs that are still useful and mostly aligned with the code.

### D3: Verification is search-based plus OpenSpec validation

After cleanup, run targeted searches for stale current-facing terms:

- `/v1/words/next`
- `GET /v1/learning/cards`
- `SQLite` / `sqflite`
- `VocabularyRefreshWorker`
- `SyncWorker`
- `prefetchBatch`
- `fetchRecentWords`
- `VOCAB_PREFETCH_LIMIT` / `vocabPrefetchLimit`

Some terms may remain when they describe current negative behavior, such as "SQLite backward compatibility is not supported" or "`GET /v1/words/next` has been removed"; those are acceptable and should be reviewed manually.

## Risks / Trade-offs

- [Risk] Deleting dated research loses some project memory. -> Mitigation: keep current docs and OpenSpec changes as authoritative history.
- [Risk] Search terms can produce false positives in valid removal notes. -> Mitigation: manually inspect remaining matches.
- [Risk] Docs can drift again quickly while active changes are still in progress. -> Mitigation: add an explicit documentation hygiene spec and verification task.
