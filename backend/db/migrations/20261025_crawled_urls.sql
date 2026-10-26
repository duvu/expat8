-- Migration: remember every URL the internet content crawler has evaluated so rejected or already
-- ingested pages are never fetched or sent to the LLM twice.

CREATE TABLE IF NOT EXISTS crawled_urls (
  url_hash TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  feed_url TEXT,
  status TEXT NOT NULL,
  reason TEXT,
  cefr_level TEXT,
  quality INTEGER,
  article_id TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_crawled_urls_created ON crawled_urls (created_at DESC);
