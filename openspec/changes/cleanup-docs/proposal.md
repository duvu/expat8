## Why

The repository still contains current-facing documentation that describes removed or superseded behavior, including `/v1/words/next`, SQLite/sqflite local storage, removed mobile workers, and old prefetch paths. This slows debugging because search results lead developers to docs that contradict the live ObjectBox and `POST /v1/learning/cards` codebase.

## What Changes

- Add an explicit documentation hygiene requirement for current project docs.
- Remove or update documents that present obsolete architecture as current behavior.
- Keep only documents that either match the current codebase or are clearly historical and not likely to be followed as setup/API guidance.
- Fix current README/setup/API endpoint lists that still mention removed routes.

## Capabilities

### New Capabilities
- `project-documentation-hygiene`: Defines when project documentation must match current code, when stale documents should be deleted, and how historical notes may remain.

### Modified Capabilities
- None.

## Impact

- **Docs**: `docs/*.md`, `README.md`, `mobile/README.md`, `backend/README.md`, and OpenSpec docs/spec references found during audit.
- **Code/API**: No runtime code or API behavior changes.
- **Risk**: Deleting dated research notes can remove historical context; the cleanup favors current correctness and search hygiene per the request.
