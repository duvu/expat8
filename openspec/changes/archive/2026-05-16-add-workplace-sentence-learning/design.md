## Context

The app already has an offline-first vocabulary learning flow backed by bundled local storage behavior, background refill, and an article-driven backend enrichment pipeline. The requested change introduces a second learning surface for common workplace English sentences, with the same immediate-start expectation: the learner should open the feature and study without waiting for the network.

This change crosses mobile UI, mobile persistence, backend persistence, backend worker enrichment, and API contract boundaries. It also needs a clean separation from vocabulary so sentence learning can ship quickly without destabilizing existing word selection, study-event sync, or exam behavior.

## Goals / Non-Goals

**Goals:**
- Add a dedicated mobile section for workplace sentence study that works immediately from a bundled 100-sentence starter pack.
- Keep sentence study local-first so visible cards never depend on a live backend request.
- Add backend sentence generation and storage that reuses the existing asynchronous article-processing model rather than generating content inline during learner requests.
- Continuously refill the mobile sentence inventory from backend-prepared content in the background.
- Preserve room for future sentence difficulty, sync, or review workflows by assigning stable sentence identifiers and source metadata.

**Non-Goals:**
- Replacing the current vocabulary learning flow or merging sentence records into the vocabulary data model.
- Adding sentence-specific proficiency scoring, exam coverage, or cross-device sentence progress sync in v1.
- Building a separate admin sentence authoring workflow in this change.
- Supporting non-English workplace sentence tracks in the first release.

## Decisions

### 1. Introduce a separate sentence-learning domain instead of extending vocabulary records
The mobile app and backend will use dedicated workplace-sentence models, repositories, and feed APIs rather than overloading the existing vocabulary item shape.

Rationale:
- Sentence cards need different payload fields and selection rules than word cards.
- Keeping a separate domain reduces regression risk in the current vocabulary flow.
- Stable sentence IDs still allow future progress sync if the product later needs it.

Alternatives considered:
- Extend vocabulary items with `entry_type=sentence`: rejected because it complicates existing card rendering, review logic, and study-event semantics.
- Store sentences as article-only metadata with no dedicated feed: rejected because mobile needs a stable refill contract.

### 2. Seed the feature from a bundled JSON asset containing 100 curated workplace sentences
The mobile app will ship a versioned starter asset embedded in the app package. On first sentence-mode entry, the app imports any missing starter sentences into ObjectBox before showing the first card.

Rationale:
- Guarantees instant first-use experience even offline.
- Keeps starter quality under product control.
- Avoids coupling first launch success to backend availability.

Alternatives considered:
- Fetch the first pack from backend on demand: rejected because it violates the no-wait requirement.
- Store starter sentences only in code constants: rejected because a structured asset is easier to update, validate, and test.

### 3. Reuse the asynchronous article-processing worker to generate sentence candidates
The backend worker will extend the existing article enrichment pipeline to extract or generate workplace-useful English sentences from uploaded articles. Sentence persistence happens only in the background worker, never during learner-facing feed requests.

Rationale:
- Matches the current vocabulary architecture.
- Keeps learner-facing APIs fast and predictable.
- Lets sentence generation share article ownership, publication gating, and existing operational tooling.

Alternatives considered:
- Generate sentences inline during mobile refill: rejected because it adds latency and failure modes to study.
- Require manual sentence upload only: rejected because the user asked for article-driven growth similar to vocabulary.

### 4. Sentence refill uses a read-only backend feed and local low-watermark refill behavior
Mobile will maintain a dedicated local sentence inventory. When available sentence count drops below a configured threshold, a background worker requests a sentence batch from a new backend feed endpoint and merges unseen items locally.

Rationale:
- Preserves local-first study behavior.
- Avoids blocking visible sentence navigation on network calls.
- Keeps refill mechanics close to the current vocabulary bootstrap pattern.

Alternatives considered:
- Request one sentence per swipe: rejected because it would reintroduce visible latency.
- Replace the local store wholesale on each refill: rejected because it complicates offline continuity and dedupe.

### 5. V1 sentence progress stays local-only
The first version tracks sentence availability and simple local completion state on device, but does not add backend sentence study-event sync, sentence SRS scheduling, or sentence proficiency analytics.

Rationale:
- The user request centers on immediate availability plus continuous backend loading.
- This keeps the first implementation tractable while preserving a future upgrade path.
- It avoids mixing sentence study semantics into the existing word-based study-event contract.

Alternatives considered:
- Reuse the current study-event API for sentences immediately: rejected because it would require contract, persistence, and reporting changes beyond the requested scope.

## Risks / Trade-offs

- [Generated sentence quality may be uneven] -> Mitigation: ship a curated bundled starter pack, validate backend-generated sentence length/language/content, and only serve sentences sourced from successfully processed published articles.
- [Separate sentence storage duplicates some vocabulary infrastructure] -> Mitigation: reuse shared persistence helpers, worker orchestration, and local refill patterns where possible while keeping the domain models separate.
- [Local-only progress does not follow the learner across devices] -> Mitigation: persist stable sentence IDs and source metadata so a future sync change can layer on without reformatting stored content.
- [Sentence inventory can grow too large on device] -> Mitigation: define a dedicated sentence cache cap and prune oldest non-starter, non-active sentence records on each remote batch merge.

## Migration Plan

1. Add backend persistence, generation, and read-only feed support behind the new sentence capability without changing current vocabulary APIs.
2. Backfill sentence records from newly processed articles after backend deployment; optionally trigger reprocessing for selected published articles if initial seed volume is too low.
3. Ship the mobile release with the bundled 100-sentence asset and the new sentence-learning entry point.
4. Monitor refill success, local import behavior, and sentence inventory growth before considering sentence sync or broader language support.

Rollback:
- Hide or disable the mobile sentence-learning entry point in a follow-up release if the experience is not ready.
- Stop backend sentence generation and feed serving without affecting the existing vocabulary pipeline.
- Bundled starter sentences are additive local content, so rollback does not require data migration.

## Open Questions

- Should article-derived sentences become eligible automatically once their source article is published, or should a later change add explicit reviewer approval for sentence candidates?
- What exact local completion states does product want for v1 sentence study: unseen/seen only, or unseen/learning/mastered similar to vocabulary?
- Should the new mobile section reuse the existing swipe card shell verbatim, or use a lighter sentence card layout while keeping the same offline-first navigation behavior?
