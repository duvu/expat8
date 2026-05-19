## Context

The mobile app already exposes a log viewer with a send-to-server action. The client builds a sanitized text archive, signs `POST /v1/mobile/log-archives` with app credentials, and sends it as `text/plain`. The backend has raw-body capture, app credential verification, a file-backed log archive store, and admin routes for listing and retrieving uploaded archives.

The current risk is that these pieces are tested mostly in isolation: backend tests exercise a helper-generated signed upload, and mobile tests inspect generated headers and payloads without proving the produced request is accepted by the backend verifier. The fix should start from an end-to-end reproducer so the root cause is pinned down before changing signing, raw body, route, or storage behavior.

## Goals / Non-Goals

**Goals:**

- Reproduce the failing mobile log upload path with a mobile-equivalent signed request.
- Fix the smallest incorrect behavior in the mobile client, backend request pipeline, configuration, or storage path.
- Preserve HMAC app credential requirements for `/v1/mobile/log-archives`.
- Preserve log sanitization before upload and prevent empty archives from being sent.
- Verify the uploaded archive can be listed and read through admin log archive APIs.

**Non-Goals:**

- Adding crash reporting, automatic background uploads, or new third-party telemetry.
- Changing log retention duration or archive storage backend.
- Relaxing app credential, admin token, or session-token security rules.
- Uploading unsanitized local database state or non-log diagnostics.

## Decisions

- Use a failing end-to-end test as the primary guide. This is preferred over guessing because signing failures can come from canonical path/query construction, content hashing, body encoding, header casing, compiled credentials, or middleware behavior.
- Keep the upload payload as sanitized UTF-8 text. This matches the existing mobile export format, avoids multipart parsing, and lets the backend verify the exact raw bytes used for the HMAC content hash.
- Keep `POST /v1/mobile/log-archives` under the normal `/v1/*` app credential guard. Unsigned upload would make support logs vulnerable to unauthenticated storage abuse.
- Treat user session as optional. Anonymous devices must still be able to send support logs, while signed-in sessions should attach the user ID when the bearer token is valid.
- Verify through admin APIs after upload instead of only checking the upload response. This proves persistence, metadata indexing, retention metadata, and content streaming all work together.

## Risks / Trade-offs

- HMAC/body mismatch across Dart and Node implementations -> Add a cross-stack verification test or an equivalent fixture that signs exactly the payload bytes sent over HTTP.
- Production-only configuration drift, such as wrong compiled app credentials or archive directory permissions -> Include environment/config checks in the investigation and document any deploy-time fixes needed.
- Large logs can hit body limits -> Keep existing size limits and add clear failure coverage rather than increasing limits without evidence.
- Log uploads may contain sensitive data if sanitization regresses -> Keep repository-level sanitizer tests and avoid bypassing `exportLogs` in the send-to-server path.
- Admin retrieval can pass while mobile upload still fails -> Smoke test from a mobile-style signed request all the way to admin content retrieval.

## Migration Plan

- No data migration is expected.
- Deploy backend/mobile changes normally after tests pass.
- If only backend changes are needed, server deploy is sufficient. If mobile signing/config changes are needed, rebuild the mobile binary because `--dart-define` values are compiled in.
- Roll back by redeploying the previous backend image or previous mobile build if the upload path causes regressions.

## Open Questions

- Is the observed failure from a local/dev build, production Android build, or both?
- Does the failing client receive a backend response status/body, a timeout, or a network/connectivity error?
