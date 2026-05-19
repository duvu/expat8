## Why

The dashboard already covers articles, users, prompts, and exam content, but there is no dedicated operations surface for understanding system health, backend readiness, or uploaded app logs. As the mobile app grows, admins need a fast way to inspect failures, view warning/error trends, and recover diagnostic logs without jumping between browser tabs and backend terminals.

## What Changes

- Add a dedicated dashboard operations area for system visibility and troubleshooting.
- Add a modern logs experience that surfaces uploaded log files, backend health, and warning/error context in one place.
- Add a mobile log upload action so users can send sanitized logs from the device to the server when they need support.
- Store uploaded logs on the server as files with default retention of 3 days and a maximum archive size of 100 MB.
- Add dashboard-facing health and status views so admins can quickly confirm backend readiness, archive state, and recent failures.
- Refresh the dashboard shell and page layouts to feel more modern and usable on desktop and smaller screens.
- Add triage-oriented UX for searching, filtering, and drilling into failures instead of forcing manual log inspection.

## Capabilities

### New Capabilities

- `dashboard-admin-ops`: The dashboard provides a dedicated operations workspace for health visibility, logs, warnings, and troubleshooting-focused UI.
- `backend-log-storage`: The backend accepts uploaded log files from the mobile app, stores them as files, and enforces archive retention and size limits.

### Modified Capabilities

- `dashboard-nav-shell`: The dashboard shell adds a new ops-oriented navigation surface and layout treatment for operational pages.
- `mobile-system-logging`: The mobile log viewer adds a send-to-server action that uploads sanitized log files to the backend.

## Impact

- `expat8-dashboard/src/app/*`: new ops pages, layout updates, and dashboard navigation changes.
- `expat8-dashboard/src/components/*`: shell, sidebar, toolbar, and table/card patterns for a modern admin experience.
- `expat8-dashboard/src/lib/*`: data-fetching helpers for health/status/log views.
- `mobile/`: log viewer action to upload sanitized log files to the server.
- Backend/admin APIs: new log-upload and log-archive read endpoints, plus retention enforcement for uploaded files.
- UX: stronger focus on search, filters, severity badges, recent failures, and quick status scanning.
