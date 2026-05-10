## Why

Article ingestion currently extracts candidate terms locally and uses LLM enrichment only after a token is already selected. We want the worker to use the LLM more directly to suggest words and phrases from articles, classify them, and assign levels, especially for longer articles that should be split into smaller chunks for reliable processing.

## What Changes

- Add an LLM-backed article vocabulary suggestion flow that can propose words and phrases directly from article chunks.
- Add chunking behavior for long articles so the worker can process article text in smaller pieces.
- Extend article vocabulary output to include suggestion classification and level metadata for each extracted item.
- Keep validation and persistence separate so suggested items still must pass backend checks before storage.

## Capabilities

### New Capabilities
- `article-llm-vocabulary-suggestions`: LLM-backed article chunking, vocabulary suggestion, classification, and level assignment.

### Modified Capabilities
- `article-vocabulary`: Article vocabulary responses and stored extraction metadata include classification/level information for LLM-suggested items.
- `article-processing-pipeline`: Article ingestion behavior changes to chunk long articles and ask the LLM for suggestions rather than relying only on local candidate extraction.

## Impact

- Backend article-processing pipeline and worker prompt/runtime flow.
- Article vocabulary persistence and read shape for extracted suggestions.
- Long-article handling, chunking strategy, and validation logic.
- Tests and rollout verification for LLM-assisted article extraction.
