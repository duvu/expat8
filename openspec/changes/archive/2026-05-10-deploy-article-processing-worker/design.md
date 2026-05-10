## Context

The backend already has the article-processing code path: article creation/reprocessing enqueues `article_processing_jobs`, and `backend/src/worker.js` contains the consumer loop that claims jobs, runs the enrichment pipeline, and persists vocabulary artifacts. The deployed worker stack currently runs the API server and dashboard, but not the dedicated article-processing consumer, so queued jobs never drain.

The current backend server also starts the vocabulary pool scheduler, which generates general vocabulary. That is a separate flow from article ingestion. This change must keep those responsibilities distinct so the API server stays responsive while ingestion runs independently.

## Goals / Non-Goals

**Goals:**
- Run the article-processing consumer as a durable deployment service.
- Wire the worker to the same PostgreSQL database and LiteLLM settings as the backend.
- Make article jobs drain automatically without manual database intervention.
- Surface failure clearly through job status and article processing metadata.

**Non-Goals:**
- Redesign the article extraction/enrichment pipeline.
- Move article processing into the dashboard or API request path.
- Change the vocabulary schema or article-review contract.
- Replace the existing vocabulary pool scheduler or learning-card generation flow.

## Decisions

### Decision 1: Deploy a separate worker process for article ingestion

The worker should run as its own Compose service using the existing `node src/worker.js` entrypoint.

**Rationale:** The repository already distinguishes API serving from asynchronous article processing. Reusing the worker entrypoint keeps the ingestion loop isolated and avoids tying heavy LLM work to HTTP traffic.

**Alternatives considered:**
- Run ingestion inside `server.js`. Rejected because it couples ingestion throughput to API uptime and makes backpressure harder to manage.
- Trigger processing from dashboard actions. Rejected because publish/reprocess must remain durable and independent of a browser session.

### Decision 2: Share the same database and LiteLLM configuration as the backend

The worker will use the same Postgres database and the same LiteLLM runtime variables as the backend service.

**Rationale:** Job queue state and persisted vocabulary live in Postgres, and enrichment uses the same model/runtime contract as the backend ingestion pipeline.

**Alternatives considered:**
- Introduce a separate queue database. Rejected because it would split state without a functional need.
- Inline fallback-only enrichment. Rejected because it would hide the real runtime requirement and make results inconsistent across environments.

### Decision 3: Keep publish semantics separate from processing semantics

Publishing an article should remain a status change; processing should happen when the worker claims the queued job.

**Rationale:** The current code already models these as different actions. Preserving that separation keeps admin moderation simple while making ingestion retryable and observable.

**Alternatives considered:**
- Auto-process on publish inside the API handler. Rejected because it would make publish latency depend on LLM work.

### Decision 4: Make worker failure observable through job status

If processing fails, the worker should update job/article metadata so operators can see retryable failures and dead-lettered jobs.

**Rationale:** Silent failures would recreate the current problem. Operators need to know whether a published article is simply waiting, retrying, or exhausted.

**Alternatives considered:**
- Retry in-memory only. Rejected because worker restarts would lose state.

## Risks / Trade-offs

- **[Risk]** Worker can fall behind if article volume increases. → **Mitigation:** keep the worker isolated, tune interval/concurrency separately, and monitor queued jobs.
- **[Risk]** LiteLLM failures can delay ingestion. → **Mitigation:** preserve retryable job state and fail clearly when enrichment is invalid.
- **[Risk]** Compose deployments may drift if worker envs are not documented. → **Mitigation:** make worker envs explicit in the deployment spec and rollout checklist.
- **[Risk]** Operators may confuse publish with ingestion completion. → **Mitigation:** document the state machine and verify that processed vocabulary actually appears after worker drain.

## Migration Plan

1. Add the article-processing worker to the worker compose stack.
2. Pass the worker the same database and model/runtime envs used by the backend.
3. Recreate the stack and verify the worker starts and claims an existing pending job.
4. Confirm vocabulary artifacts appear in `terms`, `word_senses`, `article_terms`, and `vocabulary_review_items`.
5. Roll back by stopping the worker service if ingestion misbehaves; queued jobs remain durable in the database.

## Open Questions

- Should the worker run continuously with a short poll interval, or should it be scheduled by an external job runner?
- Do we want a separate health/readiness probe for the worker service, or is log-based verification enough for this rollout?
