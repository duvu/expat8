## Context

The backend currently exposes a small REST API through Node.js built-in HTTP:
`/health`, `/v1/words/next`, `/v1/words/recent`, and
`/v1/study-events/sync`. The `/v1/*` endpoints can currently be called without
an app-level credential, which is acceptable for local MVP work but weak for a
public app/API surface.

The security design is captured in `docs/app-credential-security.md`: protect
public API requests with `appId` and HMAC signatures, reject invalid requests
early with a generic bad request response, keep secrets in runtime
configuration, and avoid treating mobile app secrets as strong user identity.

## Goals / Non-Goals

**Goals:**

- Move backend HTTP routing to ExpressJS so security checks, raw-body capture,
  JSON parsing, and route handlers are explicit middleware layers.
- Require valid app credential headers for all `/v1/*` requests before any
  business route handler, database operation, or LiteLLM call runs.
- Verify signatures using a stable canonical request made from method, sorted
  path/query, timestamp, nonce, and SHA-256 hash of the raw request body.
- Reject missing, malformed, expired, replayed, unknown, or incorrectly signed
  credential requests as `400 { "error": "bad_request" }`.
- Add operational controls for body-size limits, nonce replay windows, active
  credential configuration, and documentation.
- Preserve the existing API payload shapes for valid requests.

**Non-Goals:**

- User login, OAuth, session management, or user authorization.
- Device attestation such as Play Integrity or App Attest.
- A database-backed credential administration UI.
- Full DDOS mitigation inside Node.js. The backend will add cheap local
  rejection paths, but volumetric attacks still require edge/WAF protection.
- Changing vocabulary generation, sync semantics, PostgreSQL schema, or mobile
  learning behavior beyond signing requests.

## Decisions

1. Use ExpressJS for the public backend HTTP surface.

   Express gives the project a conventional middleware pipeline for concerns
   that are awkward in the current single built-in HTTP handler: raw body
   capture, route grouping, app credential validation, JSON parsing, and shared
   error responses. The store and generation services should remain injected so
   unit tests can keep using in-memory stores.

   Alternative considered: keep the built-in HTTP handler and add credential
   checks at the top. That would avoid a dependency but would keep security,
   parsing, routing, and business logic coupled in one handler.

2. Mount credential protection only on `/v1/*`, while keeping `/health`
   unauthenticated.

   Health checks need to work for Docker Compose, load balancers, and uptime
   monitors without access to app secrets. The health response must stay
   minimal and avoid exposing runtime configuration.

   Alternative considered: require credentials on every endpoint. That is
   stricter but makes operational health checks harder and does not materially
   protect sensitive business endpoints more than a scoped `/v1/*` guard.

3. Capture raw request bytes before JSON parsing.

   The HMAC includes the SHA-256 hash of the raw request body, so the backend
   must verify the exact bytes the client signed. The Express pipeline should
   not use global `express.json()` before credential verification. Instead,
   `/v1/*` should run:

   ```text
   coarseIpRateLimit
     -> captureRawBodyWithLimit
     -> appCredentialGuard
     -> parseJsonFromCapturedBody
     -> v1Router
   ```

   Alternative considered: sign the parsed JSON object. That creates ambiguity
   around whitespace, property order, number formatting, and parser behavior.

4. Load app credentials from runtime environment first.

   The first implementation should read `APP_CREDENTIALS_JSON` from the
   environment, containing active app ids and secrets. This matches the current
   configuration style for database and LiteLLM settings, keeps secrets out of
   versioned files, and avoids adding a credential database before the project
   needs admin tooling.

   Alternative considered: add `app_credentials` to PostgreSQL now. That helps
   dynamic rotation, but it also creates secret-material storage and management
   decisions that are larger than this first hardening change.

5. Use generic rejection responses for all credential failures.

   The backend should return `400 { "error": "bad_request" }` for missing
   headers, unknown app ids, bad signatures, expired timestamps, replayed
   nonces, oversized bodies, and malformed JSON after credential verification.
   Logs and metrics can classify failure reasons internally without exposing
   those details to callers.

   Alternative considered: use `401` or detailed errors. Detailed responses
   make client integration friendlier, but they also help attackers distinguish
   valid app ids, timestamp windows, and signature mistakes.

6. Start with in-memory nonce replay protection.

   The current Docker Compose backend runs one backend service instance. An
   in-memory TTL nonce cache is enough for that topology and can be tested
   without adding Redis. The design should make this cache injectable so a
   shared Redis-backed implementation can replace it when multiple backend
   instances are deployed.

   Alternative considered: add Redis now. It is the right choice for
   multi-instance production, but it adds operational scope before deployment
   topology requires it.

## Risks / Trade-offs

- Mobile app secret extraction -> Treat app credentials as request hardening,
  not user identity; keep rotation/revoke documented and plan attestation later.
- Existing tests and local curl commands break -> Add signing helpers, sample
  dev credentials, and documentation for signed requests.
- Raw body capture conflicts with Express JSON parsing -> Keep JSON parsing
  scoped after credential verification and test POST body handling explicitly.
- In-memory nonce cache misses replay across multiple instances -> Document the
  limitation and keep the nonce store interface replaceable with Redis.
- Express migration changes route behavior accidentally -> Preserve existing
  valid-response contracts and cover health, word feed, recent words, sync, 404,
  and error paths in tests.
- Generic `400` responses reduce client diagnostics -> Provide internal logs and
  test fixtures so developers can diagnose without leaking details publicly.

## Migration Plan

1. Add ExpressJS as a backend dependency and migrate app creation to an Express
   app while preserving store and generation-service injection.
2. Add app credential configuration parsing and test/development credentials.
3. Add raw-body capture, credential verification, nonce cache, and body-limit
   middleware for `/v1/*`.
4. Move existing routes into an Express router mounted after credential
   middleware.
5. Update tests so valid API requests are signed and invalid credential cases
   are covered.
6. Update contracts and setup/security documentation with required headers and
   environment configuration.
7. Deploy with active app credentials in runtime environment.

Rollback is to redeploy the previous backend image or disable the new public
route path before credentials are required. Because this change does not alter
the database schema, rollback does not require data migration.

## Open Questions

- Will the first public deployment run a single backend instance or multiple
  instances behind a load balancer?
- Which edge layer will enforce coarse DDOS protection: Cloudflare, nginx, load
  balancer rules, or an API gateway?
- How will mobile production credentials rotate in practice: app update, remote
  config, or a future attestation-token exchange?
