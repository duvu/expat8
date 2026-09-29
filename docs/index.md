# Expat8 Documentation Index

This directory contains durable project documentation for the Expat8 workspace. The canonical API contract remains [`contracts/api.md`](../contracts/api.md); docs here summarize how the repo is structured, operated, tested, and extended.

## Start Here

- [Project Overview](project-overview.md) — product scope, repo shape, shipped capabilities, and important invariants.
- [Developer Setup](developer-setup.md) — local prerequisites, install commands, configuration, and common workflows.
- [Architecture Guide](architecture-guide.md) — runtime topology, request pipeline, data ownership, and background processing.

## Operations (vận hành production)

Start at [ops/README.md](ops/README.md): production map, tools, rules, open items and known risks.

- [Deploy](ops/deploy.md) — build/push image, migrate (direct to Postgres), recreate, verify, rollback.
- [Mobile Release](ops/mobile-release.md) — version bump, tag, Android Release workflow, in-app update upload, hotfix.
- [Backup & Restore](ops/backup-restore.md) — nightly backup script, monthly restore drill, production restore.
- [Monitoring](ops/monitoring.md) — `ops-check` cron, daily checks, log queries, events to watch, thresholds.
- [Troubleshooting](ops/troubleshooting.md) — symptom → checks → fix for API, auth, DB, worker, LLM, sync, releases, disk.
- [Secrets](ops/secrets.md) — inventory, rotation procedures, keystore, incident response.
- [Maintenance](ops/maintenance.md) — routine schedule, log/disk/image cleanup, database checks, account deletion.

## Module Guides

- [Backend Guide](backend-guide.md) — Node.js/Express service layout, auth pipeline, storage, workers, migrations, and commands.
- [Mobile Guide](mobile-guide.md) — Flutter/ObjectBox app architecture, compile-time config, local-first learning, and release builds.
- [Dashboard Guide](dashboard-guide.md) — Next.js admin dashboard setup, environment, integration model, and admin workflows.
- [Mobile System Logging](mobile-system-logging.md) — on-device structured logs, categories, export and upload.

## Reference

- [API Guide](api-guide.md) — authentication model, endpoint groups, error conventions, and contract ownership.
- [Deployment Guide](deployment-guide.md) — local Compose stack and production environment reference (step-by-step runbook: [ops/deploy.md](ops/deploy.md)).
- [Testing Guide](testing-guide.md) — backend, mobile, dashboard, migration, and manual smoke-test commands.
- [Canonical Release Path](canonical-release-path.md) — three-stage mobile release and update distribution model.
- [App Credential Security](app-credential-security.md) — HMAC credential design and signing details.
- [Speaking Audio Privacy](20260509-speaking-audio-privacy.md) — speaking recordings stay on device; what may be synced.
- [Privacy Policy](privacy-policy.md) — user-facing privacy policy.
- [Seed Vocabulary](seed-vocabulary.md) — bundled offline vocabulary and how it is generated.
- [Release Notes](release-notes.md) — shipped changes by release.
- [System Architecture v2](architecture.md) — detailed Vietnamese architecture narrative.

## Product and Planning

- [System Review & Proposals (2026-09-28)](20260928-system-review-and-proposals.md) — review hiện trạng sản phẩm/kiến trúc, rủi ro (P0–P2) và đề xuất theo lộ trình.
- [Engagement Features Proposal (2026-09-28)](20260928-engagement-features-proposal.md) — streak, Daily Loop, nhắc học, chấm phát âm, nhập vai AI.
- [Word Blaster Game Design (2026-09-28)](games/20260928-word-blaster-game-design.md) — thiết kế game bắn từ vựng (epic #26, issues #27–#36).
- [Project Roadmap 2026-2027](20260530-project-roadmap-12-month.md) — evidence-gated 12-month roadmap, phase gates, reliability tracks.
- [Product Roadmap 2026-2028](20260509-expat8-product-roadmap-2026-2028.md) — longer-term staged product direction.
- [Phase 0–3 Speaking Foundation](20260509-expat8-phase-0-3-speaking-foundation.md) — speaking feature foundation scope.

## Archive

[archive/](archive/) holds dated reports kept for history: commit reports, one-off investigations, past deploy reports and runbooks (including the 2026-09-28 prod-readiness runbook, now covered by [ops/deploy.md](ops/deploy.md)), and the old MVP setup notes. They describe the system at the time they were written; do not follow them as current instructions.
