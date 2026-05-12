## Context

The exam feature currently assumes a single vocabulary-exam flow and persists results as part of the online submission path. The new requirement splits exam behavior by active language and introduces an offline-first result path so the user is not blocked by backend latency or outages.

This change spans mobile exam routing, local persistence, background synchronization, and backend exam result ingestion. The design must preserve the existing exam UX while preventing cross-language content leakage and ensuring completed attempts are not lost when the network is unavailable.

## Goals / Non-Goals

**Goals:**
- Keep exam content strictly isolated by active language.
- Store exam results locally before any backend sync attempt.
- Synchronize local exam results to the backend asynchronously and retry failures.
- Keep exam completion responsive even if backend submission is slow or unavailable.

**Non-Goals:**
- Changing exam scoring thresholds or result presentation details.
- Reworking learning-session SRS behavior.
- Adding new exam certificate behavior beyond existing result sync needs.

## Decisions

### Use language as the primary exam partition

Exam generation, filtering, and validation should key off the active language instead of topic-level selection. That keeps English and Chinese exam pools disjoint and makes content isolation explicit.

Alternative considered: keep topic-based selection and apply language filters later. Rejected because it leaves room for accidental cross-language leakage in question generation and distractor selection.

### Persist exam attempts locally before backend submission

The mobile client should write the completed attempt to local storage immediately, then enqueue a background sync job. That ensures result capture is not coupled to request latency.

Alternative considered: wait for backend acknowledgment before writing local state. Rejected because it would make the completion flow brittle and could lose attempts during connectivity failures.

### Make backend sync idempotent

The sync payload should carry a stable client attempt identifier so repeated submissions do not create duplicates. The backend should accept retries as the normal path.

Alternative considered: rely on one-shot submissions only. Rejected because mobile background sync must tolerate retries, restarts, and offline recovery.

### Keep local result state as source of truth until sync succeeds

Mobile UI should read the saved local result first and treat backend sync as a durability concern, not as a prerequisite for showing completion.

Alternative considered: hold results in memory until sync completes. Rejected because app restarts would lose the attempt and the user would experience false completion.

## Risks / Trade-offs

- [Risk] Local result records can diverge from backend state if sync fails repeatedly. → Keep stable attempt IDs, retry in background, and surface sync status in logs/telemetry.
- [Risk] Language filtering bugs can still leak content if one selector path is missed. → Add spec and test coverage at the question-generation boundary and the UI rendering boundary.
- [Risk] Deferred sync may delay certificate availability. → Keep certificate generation tied to eventual backend sync and avoid blocking the result screen on it.

## Migration Plan

1. Add local exam attempt persistence and background sync queue entries on mobile.
2. Update backend exam submission handling to accept idempotent deferred results.
3. Update exam question generation and UI routing to enforce active-language isolation.
4. Add regression tests for language separation and offline-first completion.
5. Roll out behind normal app release flow; if sync regressions appear, disable background submission path while preserving local result capture.

## Open Questions

- Should language-isolated exam content reuse the existing topic-based endpoint shape, or should the API contract move fully to language-only exam requests?
- Should the mobile UI show explicit sync status for a completed exam attempt, or remain silent unless sync fails permanently?
