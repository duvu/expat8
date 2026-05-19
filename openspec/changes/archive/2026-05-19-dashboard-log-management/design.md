## Context

The backend already stores log archives on disk via `FileLogArchiveStore` and exposes read-only admin endpoints (list, get, content, download). The dashboard at `/ops/logs` renders the list and detail pages with client-side filtering. However:
- No HTTP endpoint exists to delete an archive.
- The existing `summarizeLogArchives` utility in `ops.js` is defined but never rendered.
- The list page has no way to filter by user ID.

The `FileLogArchiveStore` has a private `#deleteArchive` method that removes both `.log` and `.json` files; we only need to expose it as a public method and add the HTTP route.

## Goals / Non-Goals

**Goals:**
- Expose `DELETE /v1/admin/log-archives/:id` in the backend (requires admin token).
- Add a "Delete" action on the dashboard detail page (`/ops/logs/[id]`).
- Add a "Delete all expired" bulk action on the dashboard list page.
- Render the stats bar (total archives, total size, active/expired count) on the list page using the existing `summarizeLogArchives` helper.
- Add a User filter input to the archive list page that filters by `source_user_id` in the existing client-side filter.

**Non-Goals:**
- Bulk delete of non-expired archives (out of scope; too destructive).
- Archive soft-delete or undo (hard delete only; retention already limits exposure window).
- Pagination of the archive list (deferred; currently 500-record cap is sufficient).
- Deletion via the mobile app or public API.

## Decisions

### D1 — Single DELETE endpoint (no bulk endpoint)
The dashboard bulk-delete-expired action will call `DELETE /v1/admin/log-archives/:id` once per expired archive client-side (via a Server Action loop), rather than adding a dedicated `DELETE /v1/admin/log-archives?state=expired` endpoint.

**Rationale**: The number of expired archives is typically small (< 50). A loop of sequential deletes avoids adding a new endpoint shape, keeps the API surface minimal, and lets the dashboard report partial failures per archive. A dedicated bulk endpoint can be added later if volume warrants it.

**Alternative considered**: `DELETE /v1/admin/log-archives` with `?state=expired` query param — rejected because it introduces a parameterized bulk-delete endpoint that is harder to audit and makes partial-failure reporting opaque to the caller.

### D2 — Server Action for delete, not an API route in the dashboard
The dashboard delete button will use a Next.js Server Action (with `revalidatePath` + `redirect`) rather than a dedicated `app/api/` route handler.

**Rationale**: The dashboard is server-rendered and uses no client-side fetch pattern; a Server Action is idiomatic for Next.js 15 and avoids a separate `/api/` route. The admin token lives in server-side env vars and never touches the browser.

### D3 — Promiscuous CORS not a concern for DELETE
The new backend endpoint is admin-only (requires `Authorization: Bearer <admin-token>`), which makes CSRF via CORS irrelevant; browsers cannot attach a custom bearer token in a cross-origin context without the server-side `Access-Control-Allow-Credentials` policy.

### D4 — Stats bar computed from already-fetched list data
`summarizeLogArchives` is already called on the full unfiltered list before the filter is applied; stats reflect the full dataset, not the current filter view. This matches the intent of a summary bar.

## Risks / Trade-offs

- [Risk] Concurrent delete + content-stream race: a client streams `/content` while an admin deletes the archive. → Mitigation: `#deleteArchive` uses `rm({ force: true })`, so the stream will throw an I/O error rather than silently returning empty content; the dashboard detail page shows an error state on any non-200 backend response. Acceptable given low concurrency in an admin ops tool.
- [Risk] Bulk-delete loop leaves some archives if the server restarts mid-loop. → Mitigation: expired archives will be cleaned up by `cleanupRetention` on the next archive upload anyway; partial deletion is not a correctness problem.
- [Trade-off] Calling `summarizeLogArchives` on the full 500-record list adds negligible CPU cost; not a concern.

## Migration Plan

1. Add `deleteArchiveById` public method to `FileLogArchiveStore`.
2. Add `DELETE /v1/admin/log-archives/:id` route in `backend/src/routes/admin.js`.
3. Document endpoint in `contracts/api.md`.
4. Add `deleteLogArchive(id)` to `expat8-dashboard/src/lib/ops-data.ts`.
5. Add Server Action file and wire delete button on detail page.
6. Add bulk-delete-expired Server Action on list page.
7. Render stats bar on list page.
8. Add user filter input (extends existing `filterLogArchives` which already handles `source_user_id` via text search — add dedicated `user` query param).

Rollback: remove the DELETE route; dashboard delete buttons are non-critical UI — removing them requires no data migration.

## Open Questions

- Should the user filter be a free-text input or a select populated from unique user IDs? → Prefer free-text (same pattern as the search box); user IDs are UUIDs not human-readable names.
