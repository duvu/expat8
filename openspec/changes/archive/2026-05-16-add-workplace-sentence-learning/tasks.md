## 1. Sentence Domain Foundations

- [x] 1.1 Define the workplace sentence payload shape and starter-asset format shared by mobile import and backend feed responses.
- [x] 1.2 Add backend persistence for workplace sentence records and source-article linkage in schema, migrations, and store interfaces.
- [x] 1.3 Add mobile ObjectBox entities and repositories for workplace sentence items and local sentence state.

## 2. Backend Generation And Feed

- [x] 2.1 Extend the article-processing worker to extract or generate workplace sentence candidates from eligible English articles.
- [x] 2.2 Validate, deduplicate, and persist accepted workplace sentence candidates with source metadata and published-article eligibility rules.
- [x] 2.3 Add the learner-facing read-only workplace sentence feed endpoint and document it in `contracts/api.md`.
- [x] 2.4 Add backend tests covering sentence validation, dedupe, unpublished-article exclusion, and feed batching behavior.

## 3. Mobile Starter Pack And Refill

- [x] 3.1 Add the bundled 100-sentence workplace starter asset and first-run importer that seeds missing starter sentences without duplicates.
- [x] 3.2 Implement dedicated background sentence refill with low-watermark triggering, unseen-item merge, and non-blocking failure handling.
- [x] 3.3 Enforce the local workplace sentence inventory cap and prune eligible non-starter sentence records before remote batch insertion.
- [x] 3.4 Run ObjectBox code generation for the new sentence entities and keep generated artifacts in sync.

## 4. Mobile Sentence Study Experience

- [x] 4.1 Add a dedicated workplace sentence entry point separate from the vocabulary learning flow.
- [x] 4.2 Build the sentence study card UI that renders required English text, Vietnamese meaning, and optional topic or source metadata.
- [x] 4.3 Implement local sentence study navigation and local completion-state updates without waiting on remote refill.
- [x] 4.4 Add mobile tests proving first-use offline startup, starter import reuse, and continued study while refill is running or failing.

## 5. Integration And Operational Checks

- [x] 5.1 Verify end-to-end that processed published articles can produce learner-visible workplace sentences while unpublished/private article sentences stay hidden.
- [x] 5.2 Document any sentence-generation operational notes, seed-data expectations, or rollout constraints needed for this feature.

## 6. Verification

- [x] 6.1 Run focused backend tests for worker, store, and sentence feed changes.
- [x] 6.2 Run `cd backend && npm test`.
- [x] 6.3 Run focused Flutter tests for sentence persistence and sentence study UI/controller behavior.
- [x] 6.4 Run `cd mobile && flutter test`.
