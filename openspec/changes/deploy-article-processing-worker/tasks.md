## 1. Worker Service Setup

- [ ] 1.1 Add a dedicated article-processing worker service to the worker Compose stack
- [ ] 1.2 Wire the worker service to the same Postgres database and LiteLLM settings used by the backend
- [ ] 1.3 Expose worker runtime settings such as interval and retry cap through environment variables

## 2. Deployment Verification

- [ ] 2.1 Confirm the worker starts cleanly with the current production-like environment
- [ ] 2.2 Verify the worker claims pending `article_processing_jobs` and advances article status
- [ ] 2.3 Confirm processed vocabulary appears in `terms`, `word_senses`, `article_terms`, and `vocabulary_review_items`

## 3. Rollout Safety

- [ ] 3.1 Add rollback guidance for stopping the worker without losing queued jobs
- [ ] 3.2 Record the final deployment notes and smoke-test results for the article-ingestion rollout
