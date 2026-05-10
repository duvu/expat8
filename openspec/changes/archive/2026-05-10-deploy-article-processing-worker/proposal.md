## Why

Published articles are reaching the dashboard, but extracted vocabulary is not appearing because the article-processing consumer is not deployed in the worker stack. The backend already queues processing jobs and contains the ingestion pipeline; the missing piece is a durable worker process that drains those jobs and persists terms, senses, and review items.

## What Changes

- Add a dedicated article-processing worker service to the worker deployment.
- Wire the worker with the backend's database, LiteLLM, and runtime settings needed for ingestion.
- Ensure the worker consumes `article_processing_jobs`, runs the extraction/enrichment pipeline, and updates article/vocabulary tables.
- Document the operational contract so published or reprocessed articles actually produce vocabulary data.

## Capabilities

### New Capabilities
- `article-processing-worker`: Background consumer that dequeues article jobs, runs extraction/enrichment, and persists vocabulary artifacts.

### Modified Capabilities
- `backend-container-deployment`: Worker deployment wiring changes so the article-processing worker runs alongside the API and dashboard services.

## Impact

- Backend worker entrypoint and runtime configuration.
- Worker deployment compose/env wiring for article ingestion.
- Database job queue utilization and vocabulary persistence flow.
- Operator documentation and rollout verification for article ingestion.
