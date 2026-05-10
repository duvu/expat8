## Why

Users can learn vocabulary through the SRS card system but have no way to formally test their knowledge across a topic or receive a credential for what they've studied. An exam feature closes the feedback loop: learners can assess readiness on demand, get a score, and earn a shareable completion certificate — increasing motivation and providing a tangible milestone.

## What Changes

- **New exam session flow** on mobile: 4-choice MCQ quiz drawing from the learner's studied vocabulary, organised by topic and language.
- **New backend exam endpoints**: generate questions from `word_senses`, persist exam results, and issue certificates.
- **New dashboard exam panel**: admins can view per-user exam attempts and results.
- Mobile `LearningScreen` gets an entry point button to launch an exam — no changes to the SRS learning loop itself.

## Capabilities

### New Capabilities

- `exam-session`: MCQ exam session on mobile — topic/language selection, 4-choice questions, per-question feedback, final score screen.
- `exam-questions`: Backend question generation from `word_senses` inventory (distractors drawn from same language/difficulty pool).
- `exam-results`: Backend persistence of exam attempts (score, topic, language, CEFR/HSK level, timestamp) and retrieval for mobile and dashboard.
- `exam-certificate`: Backend-issued completion certificate (JSON payload + shareable link) awarded when a passing threshold is met.

### Modified Capabilities

- `expat8-dashboard`: New exam results tab — read-only view of attempts per user. Existing article/vocabulary management behaviour unchanged.

## Impact

- **Mobile**: new `ExamScreen`, `ExamSessionController`, `ExamRepository` under `mobile/lib/src/exam/`. Entry-point button added to `LearningScreen`. New ObjectBox entity `ExamAttempt` for local caching.
- **Backend**: new route group `POST /v1/exam/start`, `POST /v1/exam/submit`, `GET /v1/exam/results`, `GET /v1/exam/certificate/:id`. New DB tables `exam_attempts`, `exam_questions`. All routes require standard app-credential headers.
- **Dashboard**: new "Exam Results" tab in the admin web dashboard (`expat8-dashboard`).
- **Database**: 2 new tables (`exam_attempts`, `exam_questions`); 1 migration file.
- **API contract** (`contracts/api.md`): new exam endpoint section added.
- **No breaking changes** to existing SRS, speaking, or article flows.
