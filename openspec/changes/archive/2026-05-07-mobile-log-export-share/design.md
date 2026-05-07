## Context

Mobile already has structured persisted logs, a `LogsScreen`, and `WordRepository.exportLogs()`. The current export writes JSONL to a temporary file on non-web platforms and shows the path in a SnackBar, but it does not open a native share sheet, so a real-device user cannot easily send logs through Zalo, Telegram, email, or another installed app.

Log retention is currently configured in days (`APP_LOG_RETENTION_DAYS`, default 7). The new requirement is a strict 60-minute rolling log window.

## Goals / Non-Goals

**Goals:**
- Export sanitized mobile logs as a UTF-8 text file.
- Open the platform share sheet with the exported file attached.
- Keep only the most recent 60 minutes of logs, plus the existing max-entry cap.
- Preserve the existing log viewer filters and reuse them for export.
- Keep backend/API behavior unchanged.

**Non-Goals:**
- Add backend log upload.
- Add app-specific integrations for Zalo, Telegram, or any single app.
- Guarantee that every third-party app accepts the attachment after the OS share sheet opens.
- Preserve logs older than 60 minutes for normal builds.

## Decisions

### D1: Use the native share sheet, not app-specific SDKs

Use a Flutter sharing plugin to invoke the OS share sheet with a generated text file. This gives users installed targets such as Zalo, Telegram, Messages, email, or cloud drives without taking dependencies on each app's SDK.

Alternative considered: implement direct Zalo/Telegram integrations. Rejected because it expands scope, adds app-specific auth/availability handling, and is unnecessary for support handoff.

### D2: Use `share_plus` only with a compatible version

`share_plus` is the standard Flutter plugin for platform share UI. The latest version currently requires newer Flutter/Dart/tooling than the mobile pubspec minimum, so implementation must either:

- choose a `share_plus` version compatible with the project toolchain, or
- intentionally bump mobile Flutter/Dart/Android build requirements in the same change.

The preferred implementation is to keep toolchain churn low and select the latest compatible `share_plus` version that supports file sharing on Android/iOS.

### D3: Export a controlled temp `.txt` file

`WordRepository.exportLogs()` should write a real file under the app temporary directory with a stable name such as `expat8_logs_<timestamp>.txt`, then return file metadata to the UI. The content should be UTF-8 text with a small header followed by line-delimited sanitized entries. JSONL-compatible lines are acceptable because they are still plain text and easy to parse.

On web, keep the existing in-memory payload behavior unless the implementation chooses a web download fallback. This request is primarily for mobile device sharing.

### D4: Share from the UI layer

Keep log querying/export in the repository and perform share-sheet invocation in `LogsScreen`. This avoids coupling the data layer to Flutter UI context and keeps iPad/share-position handling in the widget where a `BuildContext`/render box exists.

### D5: Enforce 60-minute rotation at persistence time

Replace day-based retention usage in `main.dart` with `Duration(minutes: 60)`. The existing `LocalDatabase.pruneLogs(maxAge: Duration, maxEntries: int)` already supports minute-level duration, so the storage pruning primitive does not need a new algorithm.

Remove or supersede `APP_LOG_RETENTION_DAYS` from current docs/config. If a config knob remains, it must not allow normal builds to retain more than 60 minutes.

## Risks / Trade-offs

- [Risk] Share plugin version conflicts with the current Flutter SDK. -> Mitigation: verify `flutter pub get`; if needed, pin a compatible `share_plus` or explicitly bump mobile SDK requirements.
- [Risk] Some share targets may ignore text file attachments. -> Mitigation: use the platform share sheet and report share result/failure in the UI; do not promise app-specific delivery.
- [Risk] 60-minute retention may remove logs before a delayed support request. -> Mitigation: users can export/share immediately after reproducing the issue; retention is deliberately privacy/storage focused.
- [Risk] Exported logs can still contain sensitive data if new log fields bypass redaction. -> Mitigation: continue using sanitized persisted `LogEntry` data and add tests for exported secret redaction.
