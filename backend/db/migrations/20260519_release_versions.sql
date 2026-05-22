-- Release versions: stores metadata for uploaded mobile release APKs.
-- APK binary files are stored on disk; this table tracks metadata.

CREATE TABLE IF NOT EXISTS release_versions (
  id TEXT PRIMARY KEY,
  platform TEXT NOT NULL,
  version_code INTEGER NOT NULL,
  version_name TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_release_versions_platform_code
  ON release_versions(platform, version_code DESC);
