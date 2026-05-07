## 1. Dependency and Retention

- [x] 1.1 Add or pin a mobile share-sheet dependency compatible with the current Flutter/Dart toolchain, or intentionally bump mobile SDK constraints if required.
- [x] 1.2 Replace day-based mobile log retention with a 60-minute rolling retention window while preserving the existing maximum-entry cap.
- [x] 1.3 Remove or supersede current `APP_LOG_RETENTION_DAYS` guidance so normal builds cannot retain mobile logs longer than 60 minutes.

## 2. Export and Share Flow

- [x] 2.1 Update `WordRepository.exportLogs()` to generate a UTF-8 `.txt` export file with sanitized persisted entries and useful metadata.
- [x] 2.2 Preserve the existing web/in-memory export behavior or provide an equivalent safe fallback for non-mobile platforms.
- [x] 2.3 Update `LogsScreen` export handling to avoid opening the share sheet when no logs match the current filters.
- [x] 2.4 Invoke the platform share sheet from the UI layer with the generated text file attached and user-friendly share text.
- [x] 2.5 Show visible feedback for no logs, share failure/unavailable, and successful share handoff without deleting persisted logs.

## 3. Tests and Validation

- [x] 3.1 Add or update repository tests for `.txt` export content, sanitized payload, empty export metadata, and 60-minute retention pruning.
- [x] 3.2 Add or update widget tests for filtered export, no-log feedback, and share invocation through an injectable share adapter.
- [x] 3.3 Run `flutter pub get`, targeted Flutter tests, `openspec validate mobile-log-export-share --strict`, and a stale-doc search for old log-retention guidance.
