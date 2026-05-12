## Why

Expat8 currently drills individual words in isolation, but language fluency is built on phrases, collocations, and idioms — units that carry meaning beyond their parts. Chinese learners in particular cannot progress without learning fixed expressions (成语, 固定搭配). Existing single-word drilling produces vocabulary that learners cannot use in context.

## What Changes

- **Extend the `words` table** with an `entry_type` column (`word` | `phrase` | `idiom`) and an `explanation` column (contextual meaning, register, usage notes) that supplements `meaning_vi` for multi-word entries.
- **Introduce idiom language tracks**: idioms are stored and queried under a separate language key (e.g. `en-idioms`, `zh-idioms`) so they form their own study and exam track, selectable independently from the base language track.
- **Unified exam across words and phrases**: when a user studies the `en` or `zh` track, exams draw from both words and phrases stored under that language — no separate queue or track split needed for phrases.
- **Add a sentence-context question type** alongside the existing meaning-choice question: the exam shows a full example sentence with the target term highlighted and the user picks the correct meaning from four choices (or the correct phrase to fill a blank). Both question types can appear in the same exam session.
- **Mobile card display adapts to entry type**: phrase/idiom cards suppress IPA and part-of-speech; show the explanation field and up to two example sentences.
- **Language picker persistence fix** (prerequisite): `ExamTopicScreen` must persist the last-selected language so it no longer resets to `en` on every rebuild.

## Capabilities

### New Capabilities
- `learning-entry-types`: Extends the word data model with `entry_type` and `explanation`; mobile card rendering adapts per type; backend insertion and AI generation pipelines populate the new fields.
- `idiom-language-tracks`: Idioms are stored under synthetic language keys (`<base>-idioms`, e.g. `en-idioms`, `zh-idioms`). The language selector on mobile exposes these tracks. Exam and learning-card endpoints already support any `target_language` string — no backend routing changes needed, only content and UI changes.
- `dual-exam-question-types`: The exam session can generate two question types — `meaning_choice` (existing: term → pick meaning) and `sentence_context` (new: sentence with term highlighted → pick meaning). Question type is assigned per question during session creation; mobile renders each type with the appropriate layout.

### Modified Capabilities
- `srs-card-selection`: New cards now include `entry_type` in the response card shape; `part_of_speech` and `ipa` are nullable for phrase/idiom entries.

## Impact

- **Backend DB**: migration adds `entry_type TEXT NOT NULL DEFAULT 'word'` and `explanation TEXT NOT NULL DEFAULT ''` to the `words` table.
- **Backend logic**: `startExamSession` assigns question type per question (roughly 60% meaning-choice, 40% sentence-context, or determined by entry_type); exam response shape adds `question_type` and `sentence` fields.
- **Backend API contract** (`contracts/api.md`): word shape, exam question shape, and `POST /v1/learning/cards` response updated.
- **Mobile card rendering**: `LearningCardWidget` branches on `entry_type`; phrase/idiom layout removes IPA row, adds explanation and register.
- **Mobile exam UI**: `ExamQuestionWidget` handles `sentence_context` question type (sentence displayed above choices); language picker saves last selection.
- **Seeding/content**: default seed words gain `entry_type: 'word'`; new phrase/idiom seed data added for both `en` and `zh-idioms` tracks.
