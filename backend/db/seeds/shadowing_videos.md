# Shadowing Video Seed Notes

Apply after `20260525_shadowing_videos.sql`.

This repo does not auto-apply a fixed shadowing seed because YouTube caption
tracks can change or disappear over time. For local/dev verification, keep a
small curated catalog by promoting videos that the import endpoint currently
resolves successfully.

## Recommended workflow

1. Start the backend with valid app credentials.
2. Import a candidate learner video through `POST /v1/shadowing/videos` and
   confirm it returns `201` or `200` instead of `422 transcript_unavailable`.
3. Inspect the canonical video row that was created or reused:

```sql
SELECT id, source_url, title, transcript_language, transcript_source
FROM shadowing_videos
ORDER BY created_at DESC
LIMIT 10;
```

4. Promote the canonical video into the curated catalog:

```sql
INSERT INTO shadowing_video_entries (
  id,
  video_id,
  entry_type,
  visibility,
  owner_user_id,
  owner_device_id,
  created_at,
  updated_at
)
SELECT
  'shadow_entry_seed_' || provider_video_id,
  id,
  'curated',
  'published',
  NULL,
  NULL,
  NOW() AT TIME ZONE 'UTC',
  NOW() AT TIME ZONE 'UTC'
FROM shadowing_videos
WHERE provider_video_id = '<youtube_video_id>'
ON CONFLICT DO NOTHING;
```

5. Verify the curated entry appears in `GET /v1/shadowing/videos?device_id=<id>`.

## Suggested starter catalog

- 2-3 English videos for local/dev smoke testing.
- 30-120 seconds each so transcript scrolling and looping are easy to inspect.
- Clear single-speaker audio.
- Manual captions when possible, or clean auto-captions as fallback.
- Avoid music-first clips or videos with dense multi-speaker overlap.

Revalidate candidate URLs before promoting them. The resolver depends on live
YouTube metadata and caption availability.
