## Why

The dashboard `/ops/logs` page already lists uploaded log archives and shows their content, but provides no way to delete archives — making it impossible to remove sensitive or erroneous uploads, keep storage clean, or act on expired records. A delete action (per-archive and bulk-expired) with a stats summary and user-ID filter covers the remaining management gap needed for day-to-day ops.

## What Changes

- Add `DELETE /v1/admin/log-archives/:id` backend endpoint to remove a single archive by ID.
- Add a delete button on the dashboard archive detail page (`/ops/logs/[id]`) that calls the new endpoint and redirects back to the list on success.
- Add a "Delete all expired" action on the archive list page that bulk-deletes all archives whose `retention_state` is `expired`.
- Show a stats bar on the archive list page (total archives, total size, active vs. expired counts) using the existing `summarizeLogArchives` utility that is currently unused.
- Add a **User** filter input to the archive list page (filters by `source_user_id` in the existing client-side filter).

## Capabilities

### New Capabilities
- `dashboard-log-management`: Delete single and bulk-expired log archives via a new backend endpoint; display a stats summary and user-ID filter on the dashboard log list page.

### Modified Capabilities
<!-- no existing capability specs change their requirements -->

## Impact

- **Backend**: new route module or addition to existing log-archives handler; new `DELETE /v1/admin/log-archives/:id` in `contracts/api.md`.
- **Dashboard**: `ops-data.ts` gains a `deleteLogArchive` data function; list page gets stats bar + user filter + bulk-delete action; detail page gets delete button + Server Action redirect.
- **No mobile changes**: upload flow is unchanged.
- **No schema changes**: deletion is a logical removal; no new DB columns required.
