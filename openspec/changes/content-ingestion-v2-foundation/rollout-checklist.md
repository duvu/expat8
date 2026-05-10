# Staged Rollout Checklist — content-ingestion-v2-foundation

This document is the operational gate for broad enablement of the content ingestion pipeline.
Work through each stage in order. Abort and execute the rollback drill at any red check.

---

## Pre-flight (run before any deploy)

- [ ] `cd backend && npm test` — all tests pass, ≤ 2 skipped (live-Postgres only), 0 fail
- [ ] `cd mobile && flutter test` — all tests pass, 0 fail
- [ ] `cd backend && npm run verify:migrations` — no drift between schema.sql and applied migrations
- [ ] Confirm Z440 host is reachable: `ssh -i deployment/worker-z440/ssh/id_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes <host> echo ok`
- [ ] Docker image for this release is built and pushed: `docker.x51.vn/x-ai/expat8-backend:<YYYYMMDD.HHMM>`

---

## Stage 1 — Additive DB migrations

Run each migration script once against production Postgres. All are additive; no destructive statements.

| Order | File | Tables / Indexes created |
|-------|------|--------------------------|
| 1 | `backend/db/migrations/20260509_content_ingestion_v2.sql` | `articles`, `article_processing_jobs`, `terms`, `word_senses`, `article_terms`, `content_packs`, `content_pack_items` |
| 2 | `backend/db/migrations/20260510_postgres_nonce_cache.sql` | `nonces`, `nonces_expires_at_idx` |

Health check after Stage 1:

```sql
SELECT tablename FROM pg_tables WHERE schemaname = 'public'
ORDER BY tablename;
-- Must include: articles, article_processing_jobs, article_terms,
--   content_pack_items, content_packs, nonces, terms, word_senses
```

**Rollback:** These are additive. No rollback needed unless tables are populated; if empty, `DROP TABLE` each new table in reverse order.

---

## Stage 2 — Deploy API binary (new endpoints passively present)

New routes added to `backend/src/app.js`:

- `POST/GET /v1/articles` — user article upload/list
- `GET /v1/articles/:id` — article detail
- `GET /v1/articles/:id/vocabulary` — article vocabulary (auth required)
- `POST/GET /v1/admin/articles` — admin article management
- `POST /v1/admin/articles/:id/reprocess` — requeue article
- `POST /v1/admin/articles/:id/publish` — publish article
- `GET /v1/admin/review/vocabulary` — vocabulary review queue
- `PATCH /v1/admin/vocabulary/:id` — approve/reject/edit item
- `GET/GET-by-id /v1/content-packs` — content pack listing and download

Deploy steps:

1. Update `deployment/worker-z440/docker-compose.yml` image tag to new release.
2. `docker compose pull backend && docker compose up -d backend`
3. Wait for container healthy: `docker compose ps`

Readiness checks after Stage 2:

- [ ] `GET /health` returns `200`
- [ ] `GET /v1/content-packs` with valid app credential headers returns `200` with `{ "packs": [] }` (empty until content published)
- [ ] `POST /v1/articles` with valid credential + body returns `201` or `400` (not `500`)
- [ ] Existing learning flow unaffected: `POST /v1/learning/cards` still returns card list
- [ ] Rate limit check: POST > 20 articles/min from same identity returns `429 rate_limit_exceeded`

**Rollback:** `docker compose up -d backend` with previous image tag. No data migration needed — new tables are empty.

---

## Stage 3 — Replay protection (PostgresNonceCache live)

`PostgresNonceCache` is wired automatically when `DATABASE_URL` is set (see `backend/src/runtime.js`). The `nonces` table must exist (Stage 1 migration) before the API can use it.

Verify:

- [ ] `nonces` table exists in production DB (Stage 1 complete)
- [ ] API pod has `DATABASE_URL` set
- [ ] Replay test: send the same signed request twice within 5 minutes — second request must return `401 replay_detected`

**Rollback:** Remove `DATABASE_URL` from API environment or truncate `nonces` table — API falls back to in-memory nonce cache (no replay protection across restarts, acceptable short-term).

---

## Stage 4 — Start article processing worker

The worker (`backend/src/worker.js`) is a separate process. It polls for `pending_processing` articles and runs the extraction + enrichment pipeline.

Pre-start checks:

- [ ] `LITELLM_API_KEY` (or equivalent LLM key) is set in worker environment
- [ ] `DATABASE_URL` set for worker (required — no in-memory fallback for queue)
- [ ] Worker image is same tag as API

Start:

```sh
docker compose up -d worker
```

Readiness checks:

- [ ] Worker container reaches `healthy` state
- [ ] Logs show `article_processing_backlog { pending_count: 0 }` within 60 s (or > 0 if articles already queued)
- [ ] Submit a test article via `POST /v1/admin/articles`; within ~30 s, `GET /v1/admin/articles/:id` shows `status: "pending_review"` or `"processed"`
- [ ] Worker log shows `article_processing_pipeline_completed` with `accepted_count >= 0`, no `processing_failed`

**Rollback:** `docker compose stop worker`. API remains serving from existing vocabulary; no articles processed while worker is down. Processing jobs remain in `pending_processing` state and will resume when worker restarts.

---

## Stage 5 — Enable mobile content-pack sync

`ContentPackSyncService` is included in all mobile builds compiled with current `main.dart`. There is no runtime toggle — enablement is tied to the Flutter binary build.

Confirm mobile binary version:

- [ ] Build includes `ContentPackSyncService` (present since the release containing content-ingestion-v2-foundation)
- [ ] `BACKEND_BASE_URL` `--dart-define` points to production backend
- [ ] Test on device: start app, observe logs `content_pack_sync.start` then `content_pack_sync.up_to_date` or `content_pack_sync.updated`
- [ ] On sync failure, logs show `content_pack_sync.failed` with `session_continuity: 'unaffected'` — learning session must continue normally

**Rollback:** ContentPackSyncService failures are non-fatal by design. No mobile build rollback required unless sync loop causes crashes (not expected — sync is fire-and-forget).

---

## Stage 6 — Publish first content pack and validate end-to-end

1. Submit an admin article via `POST /v1/admin/articles`.
2. Wait for worker to process (check `GET /v1/admin/articles` status = `pending_review`).
3. Approve vocabulary items via `PATCH /v1/admin/vocabulary/:id` (status `approved`).
4. Publish article via `POST /v1/admin/articles/:id/publish`.
5. Verify content pack appears: `GET /v1/content-packs` returns at least one pack with items.
6. On mobile, restart app or send to background — `content_pack_sync.updated` log should appear.
7. Verify new vocabulary words appear in learning cards after next `POST /v1/learning/cards`.

- [ ] All 7 steps confirmed without error

---

## Rollback Drill

Practice this before broad enablement:

1. **Stop worker:** `docker compose stop worker` — processing pauses, serving continues.
2. **Revert API:** `docker compose up -d backend` with previous image — new endpoints 404, existing flows unaffected.
3. **Confirm health:** `GET /health` → 200; `POST /v1/learning/cards` → cards served from existing vocabulary.
4. **Restart with new image:** `docker compose up -d backend worker` — services resume where they left off; no data loss.

Timing target: full rollback and re-health in < 2 minutes.

---

## Sign-off

| Stage | Verified by | Date |
|-------|-------------|------|
| Pre-flight | | |
| Stage 1 — Migrations | | |
| Stage 2 — API deploy | | |
| Stage 3 — Replay protection | | |
| Stage 4 — Worker start | | |
| Stage 5 — Mobile sync | | |
| Stage 6 — End-to-end publish | | |
| Rollback drill | | |
