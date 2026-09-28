# Fail Closed Replay Protection

## Why

App-credential replay protection must be authoritative for protected `/v1/*` requests. If the PostgreSQL nonce store is unavailable, a signed request cannot be safely proven fresh. Accepting the request during connection failures, timeouts, failovers, pool exhaustion, or missing schema weakens the integrity guarantee for every protected endpoint.

## What Changes

- Treat every PostgreSQL nonce-store failure as `REPLAY_PROTECTION_UNAVAILABLE`.
- Return `503` from the app-credential guard without invoking application route handlers.
- Preserve the in-memory nonce cache for local and test runtimes without a database.
- Emit a low-cardinality structured log event when replay storage is unavailable, without logging nonce or signature values.
- Replace fail-open coverage with tests for storage failures, duplicate nonces, successful claims, and API guard behavior.

## Impact

- Protected requests fail closed whenever authoritative nonce storage cannot claim or reject the nonce.
- Clients may receive transient `503` responses during database outages instead of proceeding without replay protection.
- No database schema change is required.
