## Why

The app currently gives learners an offline-first vocabulary experience, but it does not offer the same low-latency path for practicing common workplace sentences. Adding a bundled starter set plus background sentence refill lets users begin immediately and gives the backend a reusable article-driven pipeline for growing sentence practice content over time.

## What Changes

- Add a dedicated mobile study mode for common workplace English sentences that starts from a bundled in-app starter pack of 100 sentences.
- Add background sentence refill from the backend so the mobile app can keep expanding local sentence inventory without blocking the study flow.
- Add backend storage and delivery for approved workplace sentence items generated asynchronously from article ingestion, similar to how vocabulary is prepared ahead of learner requests.
- Extend the article processing pipeline so uploaded articles can produce normalized workplace sentence candidates for later mobile distribution.
- Extend local mobile persistence so bundled and remotely fetched sentence items are stored, merged, and pruned independently from vocabulary items.

## Capabilities

### New Capabilities
- `mobile-workplace-sentence-session`: A dedicated mobile learning flow for common workplace sentences with bundled bootstrap content, local-first study, and background refill.
- `backend-workplace-sentence-feed`: Backend persistence and read APIs for serving prepared workplace sentence items to mobile clients without inline generation.

### Modified Capabilities
- `article-processing-pipeline`: The asynchronous enrichment pipeline also generates workplace sentence candidates from uploaded articles.
- `mobile-local-cache-sync`: Local ObjectBox persistence and refill rules expand to cover sentence-learning inventory alongside vocabulary.

## Impact

- Mobile Flutter app: new sentence-learning entry point, bundled content asset, local sentence repository/entities, and background refill behavior.
- Backend Node/Express worker and persistence: sentence generation, validation, storage, and learner-facing feed endpoints.
- API contract and OpenSpec coverage: new backend sentence feed contract plus updated article-processing and local-cache requirements.
