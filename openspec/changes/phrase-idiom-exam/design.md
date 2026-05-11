## Context

The `words` table stores individual vocabulary items. Exams draw from a user's studied words (`user_word_states`) and test them with a single format: show a term, pick the correct `meaning_vi` from four choices. Cards always display IPA, part-of-speech, and a single example sentence.

Chinese and English have fundamentally different vocabulary units. Phrases and idioms are mandatory learning targets that the current single-word model cannot represent well. An isolated Chinese character or English verb gives no information about collocational restrictions or pragmatic usage. A phrase or idiom needs an explanation that goes beyond a one-line Vietnamese translation.

Three gaps drive this change:
1. No data model distinction between word, phrase, and idiom entries.
2. No separate study track for idioms (which require different discovery cadence and cultural context).
3. Only one exam question format — learners never practice recognizing a phrase in context.

## Goals / Non-Goals

**Goals:**
- Add `entry_type` (`word` | `phrase` | `idiom`) and `explanation` to the `words` table with a safe, backwards-compatible migration.
- Store idioms under synthetic language keys (`en-idioms`, `zh-idioms`, `vi-idioms`) so they form an independently selectable study/exam track.
- Introduce a `sentence_context` exam question type alongside the existing `meaning_choice` type; both appear in the same session.
- Adapt mobile card rendering per entry type (suppress IPA/POS for phrases/idioms; surface explanation).
- Fix language picker persistence so the exam screen does not reset to `en` on every rebuild.

**Non-Goals:**
- Generating phrase/idiom content automatically — seeding a starter corpus is in scope; ongoing AI generation pipeline changes are out of scope for this change.
- Cloze (fill-in-blank) questions — only the highlighted-term sentence layout is in scope; open-text input is not.
- Speaking drill integration for phrases.
- Changing the SRS scheduling algorithm.

## Decisions

### D1: Idioms as synthetic language keys, not a separate column

Options considered:
- **A** `entry_type = 'idiom'` with `language = 'en'` — idioms mix into the same study pool as words.
- **B** Separate `idioms` table — clean schema, but duplicates card-selection, exam, and study-event logic.
- **C** Synthetic language key `en-idioms` — idioms stored in the same `words` table, existing `target_language` routing handles them without any backend query changes. **Chosen.**

Rationale: the entire learning stack (card selection, exam, study events, SRS) keys on `language`. Adding a new `language` value adds a new track for free. Mobile only needs to add the option to the language picker and persist the selection.

### D2: Extend `words` table in-place (no new table)

The `words` table already accepts multi-word `term` values. Adding `entry_type` and `explanation` via `ALTER TABLE ... ADD COLUMN ... DEFAULT` is a non-blocking online migration in PostgreSQL. Phrase and idiom entries reuse the same card-selection, SRS, and exam machinery — no parallel pipelines.

IPA and `part_of_speech` for phrase/idiom entries will be empty strings (already valid per the backend's `String(input.ipa || '')` normalization). No schema nullability change required.

### D3: Question type assigned per-question in `startExamSession`

`startExamSession` already builds question objects. Adding `question_type` assignment there keeps the logic server-side and client-agnostic.

Assignment rules:
- Entry has a non-empty `example` → eligible for `sentence_context`.
- Roll: 50% `meaning_choice`, 50% `sentence_context` for eligible entries.
- Entries without `example` → always `meaning_choice`.
- `sentence_context` questions include a `sentence` field (the `example` value) and a `highlight` field (the `term`).

Distractors for `sentence_context` are built identically to `meaning_choice` — three other `meaning_vi` values from the same language pool.

### D4: Language picker persists via local ObjectBox settings

`ExamTopicScreen` currently stores `_language` as ephemeral `State`. The fix: read the last-used exam language from the existing `SettingsRepository` (ObjectBox) on `initState`; write it back on every change. This gives persistence across rebuilds and app restarts without adding a new dependency.

## Risks / Trade-offs

- **Empty distractor pool for idiom tracks**: An `en-idioms` track with fewer than 4 total entries cannot generate distractors. Mitigation: seed at least 20 idiom entries per track before exposing the track in the UI; guard in `startExamSession` already catches `< 5 sourceWords`.
- **`explanation` field quality**: AI-generated phrases may have thin explanations if the generation prompt doesn't explicitly request register and pragmatic notes. Mitigation: update the AI vocabulary generation prompt (tracked as a separate follow-on task, not in scope here).
- **Mixed exam experience if phrase has empty `example`**: Falls back to `meaning_choice` silently — acceptable degradation.
- **Backwards compatibility**: Existing mobile clients will receive new fields (`entry_type`, `explanation`, `question_type`, `sentence`) and must ignore unknowns gracefully. Flutter's JSON deserialization with `fromJson` patterns typically discards unknown keys — verified safe.

## Migration Plan

1. **Backend DB migration** (additive, non-blocking):
   ```sql
   ALTER TABLE words ADD COLUMN entry_type TEXT NOT NULL DEFAULT 'word';
   ALTER TABLE words ADD COLUMN explanation TEXT NOT NULL DEFAULT '';
   ```
   Existing rows get `entry_type = 'word'`, `explanation = ''`. No downtime.

2. **Seed data update**: Add `entry_type` and `explanation` to existing seed entries; add new phrase and idiom seed entries for `en`, `zh`, `en-idioms`, `zh-idioms` tracks.

3. **Backend deploy**: standard image tag bump. No route changes, no breaking API changes.

4. **Mobile release**: new fields handled in `fromJson`; exam question layout branches on `question_type`; language picker reads/writes from settings.

**Rollback**: Remove `entry_type` / `explanation` columns (safe — no foreign keys). Revert mobile to previous build.

## Open Questions

- How many seed idioms per track are needed before a track is "launchable"? (Suggested: 20 minimum to ensure meaningful exam diversity.)
- Should `zh-idioms` cover 成语 only, or also 固定搭配 and 量词 phrases? (Suggested: start with 成语 for clarity, expand later.)
- Should the language picker show `en-idioms` and `zh-idioms` by default, or only when content exists? (Suggested: only when `≥ 5` studied entries exist for that track, same as exam guard.)
