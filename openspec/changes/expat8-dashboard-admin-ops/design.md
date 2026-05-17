## Context

The dashboard already has a shared shell, article management, user views, and prompt review screens, but it lacks a dedicated operations workspace for admins who need to diagnose failures quickly. The mobile app already emits structured logs locally, and the backend/dashboard ecosystem already has authenticated admin access patterns, so the missing piece is a cohesive ops UI that surfaces health, uploaded logs, recent warnings/errors, and drill-down context without making the operator jump between unrelated screens.

This change is a cross-cutting browser + mobile + backend workflow change. It adds a log upload path from mobile to server, a server-side file archive with retention controls, and a dashboard experience that can inspect the resulting archive alongside backend health.

## Goals / Non-Goals

**Goals:**
- Give admins a clear operations home for system health, recent failures, and warning spikes.
- Make uploaded logs easy to scan, filter, and drill into.
- Keep the UI modern, familiar, and useful on desktop first, with responsive behavior on smaller screens.
- Reuse the existing dashboard shell and auth model where possible.
- Keep the change readable for support/debugging use cases rather than general analytics.

**Non-Goals:**
- Build a full observability platform or external logging pipeline.
- Change the shape of the existing structured log schema beyond what is needed for upload and browsing.
- Replace existing article, users, or speaking prompt workflows.

## Decisions

### Decision 1: Add a dedicated operations section to the dashboard instead of scattering status widgets across existing pages

**Chosen:** A new ops area with a landing page, logs archive view, and health summary.

**Rationale:** Operators need a single place to inspect failures. Putting ops data into article or user pages would increase cognitive load and make support workflows harder to remember. A dedicated section also makes the sidebar/navigation model clearer.

**Alternatives considered:** Embedding recent logs into the home page. Rejected because it mixes editorial workflows with support diagnostics and becomes cluttered quickly.

### Decision 2: Use a triage-first layout for logs

**Chosen:** Show severity chips, source filters, recent time ranges, searchable event/message fields, and a detail drawer or expandable row for context. Logs are displayed from the server archive, not from the mobile device directly.

**Rationale:** Admins usually start with “what broke?” and then narrow to “where/when/how often?”. A triage-first layout supports that workflow better than a raw table dump.

**Alternatives considered:** A raw infinite list of log rows. Rejected because it is hard to scan and does not help identify clusters of errors or warnings.

### Decision 3: Keep the shell consistent and modernize by composition, not a rewrite

**Chosen:** Reuse the existing `PageShell`, sidebar, and toolbar pattern, then evolve spacing, hierarchy, badges, cards, and tables in the ops pages.

**Rationale:** The shell already exists and is the best place to preserve navigation consistency. The UX win comes from better content presentation, not from changing the entire app architecture.

**Alternatives considered:** Replacing the shell with a new admin layout. Rejected because it would be expensive, risky, and unnecessary for the current goal.

### Decision 4: Treat system health as read-only operational context

**Chosen:** Surface readiness/health, deployment/runtime status, and recent failure summaries as read-only signals.

**Rationale:** The goal is rapid diagnosis and confidence, not remote control. Read-only status avoids dangerous dashboard actions and keeps the scope aligned with support.

**Alternatives considered:** Add restart/kill/redeploy buttons. Rejected because operational control belongs in deployment tooling, not the browser admin UI.

### Decision 5: Store uploaded logs as files with default retention controls

**Chosen:** Accept uploaded logs from mobile as server-stored files, retain them for 3 days by default, and cap total stored log volume at 100 MB by default.

**Rationale:** File retention matches the support workflow: users can export a local log bundle, the server can archive it verbatim, and the dashboard can display or download the archive without needing to normalize all log lines into a new schema. A 3-day / 100 MB default keeps storage bounded while covering the typical time window for support triage.

**Alternatives considered:** Store logs only in database rows. Rejected because file-sized logs are simpler to archive, stream, and download while preserving the original export format.

## Risks / Trade-offs

- **[Risk] Uploaded logs may be large or numerous** → Mitigation: enforce retention-by-age and max-size eviction on the server archive.
- **[Risk] Ops pages can become visually dense** → Mitigation: use cards, filters, severity badges, and progressive disclosure instead of one huge table.
- **[Risk] More dashboard surface increases maintenance cost** → Mitigation: keep the ops area composable and shared-shell-friendly so the styling system remains consistent.
- **[Risk] Mobile logs and backend status may evolve separately** → Mitigation: define the ops requirements around stable admin-visible outcomes (health, warnings, errors, searchable context, downloadable file archive) rather than specific internals.

## Migration Plan

1. Add the new dashboard ops route(s) and shell entry point.
2. Add the mobile log upload action and backend archive storage/retention path.
3. Introduce the ops data model/UI with read-only health and uploaded log summaries.
4. Add search, severity filters, and drill-down details for triage.
5. Polish responsive behavior and visual hierarchy.
6. Validate the UX with desktop and smaller viewport tests.

Rollback is straightforward: remove the new ops route(s) and sidebar entry, leaving the existing dashboard workflows untouched.

## Open Questions

- Should uploaded logs be stored as raw text files only, or also indexed for search/aggregation?
- Do we need a dedicated backend endpoint for health and log archive browsing, or can the dashboard read existing admin endpoints?
- Which operational signals matter most for the first release: readiness, recent errors, warning spikes, upload history, or deployment status?
