## 1. Worker Service Setup

- [x] 1.1 Add a dedicated article-processing worker service to the worker Compose stack
- [x] 1.2 Wire the worker service to the same Postgres database and LiteLLM settings used by the backend
- [x] 1.3 Expose worker runtime settings such as interval and retry cap through environment variables

## 2. Deployment Verification

- [x] 2.1 Confirm the worker starts cleanly with the current production-like environment
- [x] 2.2 Verify the worker claims pending `article_processing_jobs` and advances article status
- [x] 2.3 Confirm processed vocabulary appears in `terms`, `word_senses`, `article_terms`, and `vocabulary_review_items`

## 3. Rollout Safety

- [x] 3.1 Add rollback guidance for stopping the worker without losing queued jobs
- [x] 3.2 Record the final deployment notes and smoke-test results for the article-ingestion rollout
