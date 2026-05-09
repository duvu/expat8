## Context

The backend already exposes admin article creation, reprocess, publish, article listing, and vocabulary review endpoints. The missing piece is a browser UI that lets editors operate that backend workflow without duplicating enrichment logic or inventing a second content model.

This change sits at the intersection of frontend, backend auth, and content operations:

- The backend requires app-credential headers on `/v1/*` and admin token checks on admin routes.
- The worker owns LLM calls and processing state transitions.
- The browser UI needs to stay thin and reflect backend state accurately.

## Goals / Non-Goals

**Goals:**
- Provide a Next.js-based admin dashboard for article upload, processing visibility, vocabulary review, and publish actions.
- Use the existing backend article and review routes as the source of truth.
- Keep LLM enrichment inside the worker path.
- Make the dashboard usable for content editors without exposing internal pipeline complexity.

**Non-Goals:**
- Adding new backend generation logic in the browser.
- Replacing the backend article/review data model.
- Adding a second review workflow for field-level vocabulary editing unless the backend contract changes later.

## Decisions

### Decision 1: Build a thin Next.js admin surface
- Choice: Use a browser app under `web-admin/` rather than extending mobile or embedding admin tools elsewhere.
- Rationale: The workflow is editorial and operational, not learner-facing.
- Alternatives considered: Flutter web, server-rendered admin pages inside backend, extending mobile.
- Rejected because: the dashboard needs its own navigation, forms, filtering, and review ergonomics.

### Decision 2: Treat backend responses as the canonical state
- Choice: Render article status, processing error, and vocabulary review items directly from the backend API.
- Rationale: The worker and store already own the lifecycle.
- Alternatives considered: mirror state locally in the dashboard, infer status from UI actions.
- Rejected because: that risks drift and stale review decisions.

### Decision 2b: Use server-side DB reads for dashboard detail and queue views
- Choice: Let the Next.js app read the backend database server-side for article detail and vocabulary review hydration until dedicated admin read endpoints exist.
- Rationale: The current backend contract is mutation-complete but read-light for the dashboard.
- Alternatives considered: invent a new admin detail endpoint first, or make the browser guess from list results.
- Rejected because: the first expands backend scope unnecessarily for the MVP and the second would produce an incomplete UI.

### Decision 3: Keep browser concerns separate from processing concerns
- Choice: The dashboard only submits article creation and review actions; it does not call LLM services or implement extraction logic.
- Rationale: Processing belongs to backend worker infrastructure, not the browser.
- Alternatives considered: client-side enrichment preview or direct LLM calls from the dashboard.
- Rejected because: it would leak secrets and duplicate business logic.

### Decision 4: Use a lightweight auth integration strategy
- Choice: Support the existing admin token and app-credential requirements through the dashboard transport layer.
- Rationale: `/v1/*` requests are already protected and the admin routes already expect tokens.
- Alternatives considered: relax backend auth for browser traffic, or introduce a new auth scheme just for admin UI.
- Rejected because: it expands the security surface without solving a product problem.

### Decision 5: Start with list + detail + review queue
- Choice: Scope MVP to article composer, article list/detail, and vocabulary review table.
- Rationale: Those are the minimum screens needed to operate the existing pipeline.
- Alternatives considered: add dashboards, analytics, content-pack management, or deep editor controls up front.
- Rejected because: those can be layered later once the core editorial loop is stable.

## Risks / Trade-offs

- [Browser auth complexity] → Mitigation: keep the first version narrow and align with existing app-credential/admin-token expectations.
- [Backend route gaps for deeper detail pages] → Mitigation: start with list/detail using existing responses, then add read endpoints only if the workflow truly needs them.
- [Backend route gaps for deeper detail pages] → Mitigation: use server-side DB reads in the dashboard for MVP hydration while keeping mutations on the backend API.
- [Mismatch between UI expectations and review contract] → Mitigation: keep review actions limited to approve/reject/note updates until the backend supports richer editing.
- [Overbuilding the dashboard] → Mitigation: keep the UI thin and delegate all content state to the backend.
- [Editorial flow confusion around processing states] → Mitigation: expose explicit state labels: pending_processing, processing, pending_review, published, failed.

## Migration Plan

1. Create the `web-admin/` app scaffold and shared API client.
2. Wire login and auth transport to existing backend requirements.
3. Build article list/detail pages backed by `GET /v1/admin/articles`.
4. Build article composer backed by `POST /v1/admin/articles`.
5. Build vocabulary review backed by `GET /v1/admin/review/vocabulary` and `PATCH /v1/admin/vocabulary/:id`.
6. Add publish/reprocess actions and validate the flow against the existing backend.

Rollback strategy:
- Disable the dashboard deployment while leaving backend article and review APIs intact.
- No backend schema rollback is needed for the dashboard itself because it should not introduce new persistence.

## Open Questions

- Should the dashboard use direct signed browser requests or a small backend-for-frontend layer?
- Do we need a dedicated article detail endpoint before building the detail page, or can list responses be enough for MVP?
- Should the vocabulary review screen stay limited to approve/reject/note updates until the backend supports editing extracted fields?
