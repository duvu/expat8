## 1. Audit

- [x] 1.1 Search markdown docs for removed or stale current-facing terms: `/v1/words/next`, `GET /v1/learning/cards`, SQLite/sqflite, removed workers, removed prefetch methods, and old config names.
- [x] 1.2 Classify each hit as valid historical/removal context, small stale section to patch, or contradictory document to delete.

## 2. Cleanup

- [x] 2.1 Delete contradictory docs whose main content describes obsolete storage, endpoints, unsigned API examples, or removed mobile workers/methods.
- [x] 2.2 Patch small stale sections in otherwise-current docs such as endpoint lists, setup notes, and app credential design wording.

## 3. Verification

- [x] 3.1 Re-run targeted markdown searches and manually inspect remaining matches.
- [x] 3.2 Run OpenSpec status/validation for `cleanup-docs`.
- [x] 3.3 Report deleted files, edited files, and any intentionally retained historical/removal references.
