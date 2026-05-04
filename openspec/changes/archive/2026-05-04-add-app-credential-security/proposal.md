## Why

The backend is moving toward a public app/API surface, but current `/v1/*`
endpoints accept unauthenticated requests and can reach database or LiteLLM
work before proving the caller is an approved client. We need an app-level
credential gate now so invalid requests are rejected early and consistently
before the API is exposed more broadly.

## What Changes

- Add an app credential security layer for all `/v1/*` backend API requests.
- Require clients to send `appId`, timestamp, nonce, request-body hash, and
  HMAC signature headers.
- Reject missing, malformed, expired, replayed, unknown, or incorrectly signed
  app credential requests with `400 { "error": "bad_request" }`.
- Keep `/health` unauthenticated and minimal for health checks.
- Move the backend HTTP surface to ExpressJS so app credential validation,
  body-size checks, JSON parsing, and routing are composed as explicit
  middleware.
- Add basic invalid-request resistance through body limits, timestamp windows,
  nonce replay protection, timing-safe signature comparison, and rate-limit
  hooks.
- Update backend contracts and setup/security documentation for the credential
  headers, environment configuration, and operational limits.

## Capabilities

### New Capabilities

- `backend-app-credential-security`: Covers app-level credential verification,
  ExpressJS middleware placement, replay protection, generic invalid-request
  responses, and public API hardening for `/v1/*`.

### Modified Capabilities

None.

## Impact

- Affected backend code: server/app initialization, route composition,
  request-body handling, configuration loading, HTTP utilities, and API tests.
- Affected API behavior: all `/v1/*` endpoints require valid app credential
  headers before route handlers run; invalid credential failures return a
  generic bad request response.
- New backend dependency: ExpressJS for middleware and router composition.
- Possible test helper impact: test requests must sign `/v1/*` calls or
  explicitly construct test runtimes with configured app credentials.
- Affected documentation: `contracts/api.md`, `.env.example`,
  `docs/mvp-setup.md`, README backend stack notes, and
  `docs/app-credential-security.md`.
