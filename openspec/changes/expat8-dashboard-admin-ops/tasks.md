## 1. Backend log archive

- [x] 1.1 Add a backend upload endpoint for sanitized mobile log files and persist each upload as a server-side file archive.
- [x] 1.2 Enforce authenticated upload access using the existing app-credential model.
- [x] 1.3 Add retention cleanup for uploaded logs with default limits of 3 days and 100 MB.
- [x] 1.4 Expose read-only archive metadata and download/detail access for the dashboard.

## 2. Mobile log upload action

- [x] 2.1 Add a send-to-server action to the mobile log viewer UI.
- [x] 2.2 Upload the sanitized log file to the backend archive endpoint and show success/failure feedback.
- [x] 2.3 Keep existing on-device export/share behavior intact.
- [x] 2.4 Add or update tests covering the log upload path and failure handling.

## 3. Dashboard ops workspace

- [x] 3.1 Add a dedicated Ops route/page with backend health summary cards and a recent uploads panel.
- [x] 3.2 Add a log archive table with filtering, search, and drill-down for uploaded files.
- [x] 3.3 Add a log detail view for reading archive contents and metadata.
- [x] 3.4 Show empty, loading, and failure states that are clear for support workflows.

## 4. Shell and navigation updates

- [x] 4.1 Add an Ops entry to the shared sidebar and ensure the active route highlights correctly.
- [x] 4.2 Update page titles and shell actions so the ops area feels consistent with existing dashboard pages.
- [x] 4.3 Improve desktop/mobile layout spacing and hierarchy for the new operations screens.

## 5. Verification

- [x] 5.1 Add or update spec-aligned tests for dashboard ops navigation, health rendering, and log archive browsing.
- [x] 5.2 Add or update tests for the mobile send-logs action and server upload/retention behavior.
- [x] 5.3 Run the relevant test suites and confirm the dashboard, mobile, and backend changes do not regress existing flows.
