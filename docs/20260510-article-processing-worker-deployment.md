# Article Processing Worker — Deployment Notes

**Date:** 2026-05-10
**Change:** `deploy-article-processing-worker`

## What This Is

The article processing worker is a background consumer that:
1. Polls `article_processing_jobs` for pending jobs every `ARTICLE_WORKER_INTERVAL_MS` ms (default: 1000ms)
2. Claims each job, runs the extraction → LLM enrichment → validation pipeline
3. Persists results to `article_terms`, `word_senses`, and `vocabulary_review_items`
4. Updates job and article status on success or failure

Entrypoint: `node src/worker.js` (npm script: `npm run start:worker`)

## Production Deployment (Z440)

Service name: `expat8-worker`
Image: same as `expat8-backend` (`docker.x51.vn/x-ai/expat8-backend:<tag>`)
Compose file: `/home/beou/deployment/worker-z440/docker-compose.yml`

The worker runs alongside `expat8-backend` and shares the same PostgreSQL database and LiteLLM configuration.

### Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | required | PostgreSQL connection string |
| `LITELLM_BASE_URL` | `http://10.113.213.1:5003` | LiteLLM endpoint |
| `LITELLM_API_KEY` | — | LiteLLM API key |
| `LITELLM_MODEL` | `editor8-gpt` | Model name |
| `ARTICLE_WORKER_INTERVAL_MS` | `1000` | Poll interval in milliseconds |
| `ARTICLE_WORKER_MAX_ATTEMPTS` | `3` | Max retry attempts per job before dead-lettering |
| `LOG_LEVEL` | `info` | Worker log level |
| `LOG_REDACTION_ENABLED` | `true` | Whether to redact sensitive log fields |

All Z440-specific values are set via `EXPAT8_*` prefixed vars in `.env` and injected by the Compose service definition.

## Smoke Test Results (2026-05-10)

| Check | Result |
|---|---|
| Worker starts cleanly | ✓ `article_worker_started` logged at startup |
| Worker claims pending jobs | ✓ `article_processing_job_completed` logged within ~6 min of start |
| Vocabulary persists | ✓ 38 `article_terms`, 38 `vocabulary_review_items` in DB |
| Article status advances | ✓ Both processed articles show `status: published` |
| Extraction quality | ✓ 20/20 and 18/18 accepted (0 rejected) |

Worker has been running for 4+ hours with no errors in logs.

## Rollback

If the worker behaves incorrectly, stop it without affecting queued jobs:

```bash
# On Z440 — stop worker only, jobs remain durable in DB
docker compose stop expat8-worker

# Or remove the container (jobs still safe in postgres)
docker compose rm -sf expat8-worker
```

**Safe because:** Job state (`pending_processing`, `processing`, `processed`, `failed`) is stored in PostgreSQL. Stopping the worker leaves all jobs intact. When the worker is restarted, it will resume from where it left off.

**What NOT to do:** Do not truncate `article_processing_jobs` unless you are prepared to lose all processing history. Jobs that were `processing` when the worker stopped will be retried when the worker restarts (they are not lost).

### To restart the worker after a fix:

```bash
# On Z440
cd /home/beou/deployment/worker-z440
docker compose pull expat8-worker   # if new image available
docker compose up -d expat8-worker
docker compose logs -f expat8-worker
```

### To check worker health without SSH:

```bash
# From backend container — check recent job activity
docker exec expat8-backend node -e "
  const { Client } = await import('pg');
  const c = new Client({ connectionString: process.env.DATABASE_URL });
  await c.connect();
  const r = await c.query(\"SELECT status, COUNT(*) FROM article_processing_jobs GROUP BY status\");
  console.log(r.rows);
  await c.end();
"
```

## Local Development

The repo's `docker-compose.yml` now includes `article-worker` as a service:

```bash
LITELLM_API_KEY=your-key docker compose up --build -d
docker compose logs -f article-worker
```

The worker uses the same image build as the backend. Without a `LITELLM_API_KEY`, enrichment falls back to stub vocabulary items (marked `isStub: true`, `approved: false`).

## Article State Machine

```
Upload (POST /v1/articles)
        ↓
  pending_processing
        ↓
  Worker claims job
        ↓
    processing
        ↓                           ↓
   succeeded                    failed (after max attempts)
        ↓
  pending_review   ← admin content
  processed        ← user content
```
