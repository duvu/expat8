# Design

## Overview

`PostgresNonceCache.use()` remains the single authoritative claim operation for PostgreSQL-backed replay protection. It atomically inserts `(app_id, nonce)` with `ON CONFLICT DO NOTHING`; a positive row count means the nonce is fresh, and zero means the nonce is a replay.

All errors from the insert path are mapped to `NonceStorageUnavailableError`. The app-credential guard catches only that explicit error type for the replay-store-unavailable path, emits a structured warning, returns `503`, and does not call `next()`.

## Error Mapping

The nonce cache does not attempt to distinguish recoverable PostgreSQL errors from fatal ones. Connection errors, query cancellations, timeouts, pool exhaustion, and missing-table errors all mean the backend cannot make an authoritative freshness decision for the request. They therefore share one externally visible result: `REPLAY_PROTECTION_UNAVAILABLE`.

## Observability

The guard logs `replay_protection_unavailable` with safe operational context only:

- HTTP method
- request path
- stable reason code
- error name

It must not log nonce values, signatures, app secrets, raw bodies, or full credential headers.

## Local Runtime

When no database pool is configured, the runtime continues to use `InMemoryNonceCache`. This preserves local/test behavior while PostgreSQL-backed deployments retain cross-process replay protection.
