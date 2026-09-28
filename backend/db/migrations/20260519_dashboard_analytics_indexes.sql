-- Migration: Dashboard analytics indexes
-- Adds indexes to support aggregate queries used by the analytics dashboard.

-- Study events time-series queries
CREATE INDEX IF NOT EXISTS idx_study_events_occurred_at ON study_events (occurred_at);
CREATE INDEX IF NOT EXISTS idx_study_events_device_occurred ON study_events (device_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_study_events_user_occurred ON study_events (user_id, occurred_at) WHERE user_id IS NOT NULL;

-- Speaking events time-series queries (speaking_events is created by
-- 20260509_speaking_foundation.sql). The original statement used a subquery in
-- the index predicate, which PostgreSQL rejects, so this index never existed.
CREATE INDEX IF NOT EXISTS idx_speaking_events_occurred_at ON speaking_events (occurred_at);

-- Article processing jobs status queries
CREATE INDEX IF NOT EXISTS idx_article_processing_jobs_status ON article_processing_jobs (status, created_at);
