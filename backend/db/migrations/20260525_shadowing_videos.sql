CREATE TABLE shadowing_videos (
  id TEXT PRIMARY KEY,
  source_type TEXT NOT NULL,
  provider_video_id TEXT NOT NULL,
  source_url TEXT NOT NULL,
  title TEXT NOT NULL,
  channel_title TEXT,
  thumbnail_url TEXT,
  duration_seconds INTEGER,
  transcript_language TEXT,
  transcript_source TEXT NOT NULL,
  default_playback_rate REAL NOT NULL DEFAULT 1.0,
  default_seek_back_ms INTEGER NOT NULL DEFAULT 5000,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(source_type, provider_video_id)
);

CREATE TABLE shadowing_video_segments (
  id TEXT PRIMARY KEY,
  video_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  text TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (video_id) REFERENCES shadowing_videos(id) ON DELETE CASCADE
);

CREATE TABLE shadowing_video_entries (
  id TEXT PRIMARY KEY,
  video_id TEXT NOT NULL,
  entry_type TEXT NOT NULL DEFAULT 'saved',
  visibility TEXT NOT NULL DEFAULT 'private',
  owner_user_id TEXT,
  owner_device_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (video_id) REFERENCES shadowing_videos(id) ON DELETE CASCADE,
  FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

CREATE INDEX idx_shadowing_videos_provider ON shadowing_videos(source_type, provider_video_id);

CREATE UNIQUE INDEX idx_shadowing_video_segments_video_position
  ON shadowing_video_segments(video_id, position);

CREATE INDEX idx_shadowing_video_entries_video
  ON shadowing_video_entries(video_id, updated_at DESC);

CREATE UNIQUE INDEX idx_shadowing_video_entries_curated_video
  ON shadowing_video_entries(video_id)
  WHERE entry_type = 'curated';

CREATE UNIQUE INDEX idx_shadowing_video_entries_saved_device_video
  ON shadowing_video_entries(owner_device_id, video_id)
  WHERE entry_type = 'saved' AND owner_user_id IS NULL;

CREATE UNIQUE INDEX idx_shadowing_video_entries_saved_user_video
  ON shadowing_video_entries(owner_user_id, video_id)
  WHERE entry_type = 'saved' AND owner_user_id IS NOT NULL;

CREATE INDEX idx_shadowing_video_entries_user_updated
  ON shadowing_video_entries(owner_user_id, updated_at DESC)
  WHERE owner_user_id IS NOT NULL;

CREATE INDEX idx_shadowing_video_entries_device_updated
  ON shadowing_video_entries(owner_device_id, updated_at DESC)
  WHERE owner_user_id IS NULL;
