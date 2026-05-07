## Why

Mobile debugging currently depends on in-app inspection or a file path shown in a SnackBar, which is not enough for real devices where the user needs to send logs through apps such as Zalo or Telegram. Logs also persist for the current day-based retention window, while debugging sessions need a tighter 60-minute rotation to reduce storage and privacy exposure.

## What Changes

- Add a native share action for mobile log export so users can send a generated text log file through installed share targets.
- Export sanitized persisted logs as a text file suitable for support/debugging handoff.
- Change mobile log retention from day-based retention to a 60-minute rolling window while keeping the existing max-entry cap as a second safety limit.
- Update log viewer/export UI feedback so users know whether sharing started, failed, or no logs matched the selected filters.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mobile-system-logging`: Extend log export to share a text file through the device share sheet and enforce 60-minute log retention.

## Impact

- **Mobile dependencies**: Add a share-sheet dependency such as `share_plus`; `path_provider` already exists for filesystem paths.
- **Mobile code**: `mobile/lib/src/config.dart`, `mobile/lib/main.dart`, `mobile/lib/src/data/word_repository.dart`, `mobile/lib/src/ui/logs_screen.dart`, and tests around logging/export.
- **Docs/specs**: Update mobile logging docs and OpenSpec requirements.
- **Backend/API**: No backend changes.
