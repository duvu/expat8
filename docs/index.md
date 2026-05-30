# Expat8 Documentation Index

This directory contains durable project documentation for the Expat8 workspace. The canonical API contract remains [`contracts/api.md`](../contracts/api.md); docs here summarize how the repo is structured, operated, tested, and extended.

## Start Here

- [Project Overview](project-overview.md) — product scope, repo shape, shipped capabilities, and important invariants.
- [Project Roadmap 2026-2027](20260530-project-roadmap-12-month.md) — evidence-gated 12-month execution roadmap, phase gates, reliability tracks, and non-goals.
- [Canonical Release Path](canonical-release-path.md) — committed three-stage mobile release and update distribution model (Phase 0 decision).
- [Developer Setup](developer-setup.md) — local prerequisites, install commands, configuration, and common workflows.
- [Architecture Guide](architecture-guide.md) — runtime topology, request pipeline, data ownership, and background processing.

## Module Guides

- [Backend Guide](backend-guide.md) — Node.js/Express service layout, auth pipeline, storage, workers, migrations, and commands.
- [Mobile Guide](mobile-guide.md) — Flutter/ObjectBox app architecture, compile-time config, local-first learning, and release builds.
- [Dashboard Guide](dashboard-guide.md) — Next.js admin dashboard setup, environment, integration model, and admin workflows.

## Operations and Quality

- [API Guide](api-guide.md) — authentication model, endpoint groups, error conventions, and contract ownership.
- [Deployment Guide](deployment-guide.md) — local Compose stack, Z440 production deployment, environment handling, and smoke checks.
- [Testing Guide](testing-guide.md) — backend, mobile, dashboard, migration, and manual smoke-test commands.

## Existing Reference Docs

- [App Credential Security](app-credential-security.md) — HMAC credential design and signing details.
- [MVP Setup and Limitations](mvp-setup.md) — older setup notes and known MVP constraints.
- [System Architecture v2](architecture.md) — detailed Vietnamese architecture narrative.
- [Article Processing Worker Deployment](20260510-article-processing-worker-deployment.md) — worker-specific deployment notes.
- [Product Roadmap 2026-2028](20260509-expat8-product-roadmap-2026-2028.md) — roadmap and staged product direction.
