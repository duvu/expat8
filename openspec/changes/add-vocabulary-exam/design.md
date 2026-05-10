## Context

Expat8 has a working SRS vocabulary learning loop (85/15 new/review split), a speaking drill system, and an article-based content pipeline. There is no exam or assessment capability today. Users have no way to test themselves on a topic, get a formal score, or receive a credential. This design adds a first-class exam system across mobile, backend, and dashboard without touching the existing SRS or speaking flows.

Key existing primitives:
- `word_senses` table: word, definition, language (`en`/`zh`/`vi`), difficulty (CEFR A1–C2 / HSK 1–9), `topics: List<String>` (LLM-generated).
- `user_word_states` table: per-user SRS state — tracks which words a user has studied.
- Mobile `VocabularyWord` model mirrors `word_senses` including `topics`.
- All `/v1/*` routes require app-credential headers; admin routes additionally require `x-expat8-admin-token`.

## Goals / Non-Goals

**Goals:**
- Learner can start an exam scoped to a topic + language.
- Backend generates 4-choice MCQ questions from the `word_senses` inventory using the learner's studied words as source and same-language/difficulty words as distractors.
- Exam results (score, topic, language, level, timestamp) are persisted server-side and cached locally on mobile.
- A passing score (≥ 70%) triggers backend certificate issuance; certificate has a unique ID and shareable URL path.
- Dashboard admin can browse exam attempts per user.

**Non-Goals:**
- Exam results do NOT feed back into SRS proficiency or `user_word_states`.
- No offline-only exam mode — question generation and scoring require the backend.
- No external certification body equivalence (not CEFR/HSK official exam).
- No timed exams in the first iteration.
- No speaking/listening question types — MCQ vocabulary-definition matching only.

## Decisions

### 1. Separate ExamSessionController (not an extension of LearningSessionController)
**Decision**: Introduce `ExamSessionController` and `ExamScreen` as independent classes under `mobile/lib/src/exam/`.

**Rationale**: `LearningSessionController` owns SRS state, card scheduling, and proficiency mutation. Exam sessions have different lifecycle (start → questions → submit → results), no SRS side-effects, and server-round-trip semantics. Extending the existing controller would introduce leaky coupling and risk unintended SRS mutations during exam flow.

**Alternative considered**: Reuse `LearningSessionController` with an `isExamMode` flag — rejected because flag-branching leads to brittle conditional logic across the controller.

### 2. Backend-generated questions (not client-side)
**Decision**: Mobile calls `POST /v1/exam/start` to receive a question set; the backend selects source words and distractors.

**Rationale**: Question quality (distractor selection, difficulty calibration) requires access to the full `word_senses` pool. Keeping this server-side avoids syncing large word pools to the client and enables future LLM-enriched distractor logic without a mobile release.

**Alternative considered**: Client-side generation from locally cached words — rejected because the local cache only contains the learner's studied words, making distractor diversity poor.

### 3. Topics = existing `word_senses.topics` strings
**Decision**: Exam topic scoping uses the existing LLM-generated `topics` array values (e.g., `"work"`, `"travel"`, `"people"`). No new subject taxonomy.

**Rationale**: Avoids a new taxonomy migration. The `topics` array already exists on every `word_sense`. The backend can enumerate distinct topics per language to populate the mobile topic picker.

**Limitation**: Topics are informal strings, not a controlled vocabulary. Two equivalent topics may appear as separate values (e.g., `"work"` vs `"workplace"`). Accepted as a known limitation for v1.

### 4. Backend-issued certificates with unique IDs
**Decision**: Certificate is a JSON record (`exam_certificates` table) with a UUID, issuer metadata, user ID, topic, language, level, score, and issued_at. A `GET /v1/exam/certificate/:id` endpoint returns it as JSON; the mobile app renders a shareable view.

**Rationale**: Client-side certificates are trivially forgeable. Backend issuance with a persistent UUID allows future verification queries. No external certificate authority in scope.

### 5. Exam results do NOT modify SRS state
**Decision**: Exam submission writes only to `exam_attempts`; it never updates `user_word_states` or triggers SRS rating events.

**Rationale**: SRS scheduling is calibrated to spaced repetition science. Injecting exam correctness as a rating event would distort the schedule unpredictably. The two systems are kept orthogonal.

## Risks / Trade-offs

- **Distractor quality**: Distractors drawn from the same language/difficulty pool may be too easy (unrelated domains) or too hard (near-synonyms). → Mitigation: filter distractors by same-difficulty bucket first; iterate on distractor logic post-v1 without a mobile release.
- **Topic string fragmentation**: LLM-generated topics lack a controlled vocabulary. Users may see `"work"` and `"workplace"` as separate topics. → Mitigation: backend normalises topics (lowercase, trim) and aggregates near-duplicates in the topic list endpoint. Full normalisation deferred to v2.
- **Small word pool per topic**: Learners who have studied few words in a topic may get fewer than 10 questions. → Mitigation: backend returns the actual question count in the exam start response; mobile adapts UI messaging accordingly. Minimum 5 questions required to start an exam.
- **Certificate inflation**: Any user who passes 70% threshold gets a certificate, regardless of word pool depth. → Accepted risk for v1 — certificate is a completion milestone, not an accredited qualification.
- **Dashboard load**: Exam results endpoint must not slow down existing dashboard queries. → Mitigation: `exam_attempts` is a new table with its own index on `(user_id, created_at)`; no joins to the hot `user_word_states` table.

## Migration Plan

1. Add migration `backend/db/migrations/<date>_exam_tables.sql`: creates `exam_attempts`, `exam_questions`, `exam_certificates` tables.
2. Deploy backend (all new routes; no changes to existing routes).
3. Deploy dashboard (additive new tab).
4. Release mobile (additive new screen; `LearningScreen` gets exam entry button).
5. **Rollback**: drop the 3 new tables; revert backend image; old mobile versions are unaffected (no exam entry button).

## Open Questions

- Should the topic list shown on mobile be filtered to topics the learner has actually studied words in, or the full global topic inventory? (Current plan: filter to user's studied topics — if no studied words exist for a topic, that topic is hidden.)
- Should a user be able to retake an exam for the same topic? (Current plan: yes, unlimited retakes; each attempt is recorded separately.)
- Should certificates have an expiry date? (Current plan: no expiry in v1.)
