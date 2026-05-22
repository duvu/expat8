-- Postgres-backed nonce cache for distributed replay protection.
-- Replaces the in-memory InMemoryNonceCache when DATABASE_URL is configured.
-- Nonces are claimed atomically via INSERT … ON CONFLICT DO NOTHING.
-- Expired rows are pruned lazily by PostgresNonceCache (at most once per minute).

CREATE TABLE IF NOT EXISTS nonces (
  id         BIGSERIAL    PRIMARY KEY,
  app_id     TEXT         NOT NULL,
  nonce      TEXT         NOT NULL,
  expires_at TIMESTAMPTZ  NOT NULL,
  UNIQUE (app_id, nonce)
);

CREATE INDEX IF NOT EXISTS nonces_expires_at_idx ON nonces (expires_at);
