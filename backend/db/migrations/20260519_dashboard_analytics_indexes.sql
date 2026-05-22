-- Migration: Dashboard analytics indexes
-- Adds indexes to support aggregate queries used by the analytics dashboard.

-- Study events time-series queries
CREATE INDEX IF NOT EXISTS idx_study_events_occurred_at ON study_events (occurred_at);
CREATE INDEX IF NOT EXISTS idx_study_events_device_occurred ON study_events (device_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_study_events_user_occurred ON study_events (user_id, occurred_at) WHERE user_id IS NOT NULL;

-- Speaking events time-series queries (if speaking_events table exists)
CREATE INDEX IF NOT EXISTS idx_speaking_events_occurred_at ON speaking_events (occurred_at) WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'speaking_events');

-- Article processing jobs status queries
CREATE INDEX IF NOT EXISTS idx_article_processing_jobs_status ON article_processing_jobs (status, created_at);
