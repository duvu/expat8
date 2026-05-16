## Workplace Sentence Rollout Notes

- The mobile app now ships `assets/seed_workplace_sentences/en.json` with 100 bundled starter sentences. Any content changes require a full mobile rebuild.
- The backend workplace sentence feed serves only sentences linked to published source articles. Private or unpublished article sentences stay hidden from learners.
- Article reprocessing replaces that article's workplace sentence links and prunes orphaned sentence records, so the latest processed article output becomes the source of truth.
- The first release keeps sentence completion state local-only on device. There is no backend sentence progress sync yet.
- `backend/db/migrations/20260516_workplace_sentences.sql` must be applied in environments that were initialized before this change.
