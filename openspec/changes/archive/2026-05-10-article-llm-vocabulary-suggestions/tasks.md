## 1. LLM Suggestion Pipeline

- [x] 1.1 Replace token-first article enrichment with chunk-first LLM suggestion generation
- [x] 1.2 Add deterministic article chunking for long inputs before LLM requests
- [x] 1.3 Include classification and level in the worker suggestion payloads

## 2. Validation and Persistence

- [x] 2.1 Update validation to accept normalized words and phrases returned by the LLM
- [x] 2.2 Persist suggested classification and level metadata with article vocabulary records
- [x] 2.3 Deduplicate repeated suggestions across chunks before saving

## 3. API and Read Shape

- [x] 3.1 Extend article vocabulary reads to expose classification and suggestion type metadata
- [x] 3.2 Preserve existing vocabulary access rules for owner and published articles

## 4. Verification

- [x] 4.1 Add worker tests for short-article and long-article chunking behavior
- [x] 4.2 Add worker tests for phrase suggestions, classification, and level metadata
- [x] 4.3 Smoke test an article that produces accepted vocabulary and one that only yields rejected candidates
