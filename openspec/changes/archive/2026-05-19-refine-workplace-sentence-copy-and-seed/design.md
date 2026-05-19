## Context

The sentence study feature is already implemented and working in the app, but the user-facing label still says `Workplace sentences`. The bundled English starter asset currently contains 100 sentences with Vietnamese meanings that are intentionally compact but not fully accented, so the content layer needs a quality pass without changing the overall architecture.

This change stays within the existing mobile sentence flow, the bundled JSON asset, and the markdown documentation layer. No backend contract changes are needed.

## Goals / Non-Goals

**Goals:**
- Rename the visible sentence-study label to `Sentences`.
- Expand the bundled starter pack to 150 entries.
- Normalize bundled Vietnamese meanings to proper accented Vietnamese.
- Produce a concise markdown review report covering completed and incomplete sentence-related work.

**Non-Goals:**
- Changing the sentence repository or backend feed shape.
- Introducing a new sentence domain model.
- Altering the existing refill, ObjectBox, or backend persistence architecture.

## Decisions

- Keep internal code names such as `WorkplaceSentence*` unchanged for now.
  - Rationale: the change is user-facing copy and content-focused, and renaming the internal feature would expand scope across code, tests, and docs.
  - Alternative considered: rename the domain model and repository to `Sentence*`; rejected because it would create unnecessary churn for a copy/content update.

- Update the bundled asset in-place rather than adding a new asset path.
  - Rationale: the loader already points at `assets/seed_workplace_sentences/en.json`, so keeping the path stable preserves the current import flow.
  - Alternative considered: create a new asset version or language-specific split; rejected because it adds maintenance overhead without solving the user-facing problem.

- Treat the markdown review as a deliverable under the change, not as runtime product behavior.
  - Rationale: the user explicitly asked for a report of what is complete and what remains unfinished, and that fits naturally as documentation output.
  - Alternative considered: encode the report as a spec for application behavior; rejected because it is not an app feature.

- Preserve the current sentence metadata shape (`sentence_id`, `text`, `meaning_vi`, `topic`, `source_title`, `generation_source`, `is_bundled`, timestamps).
  - Rationale: the loader, repository, and UI already depend on this shape; changing it would increase risk for no functional gain.
  - Alternative considered: add richer metadata or additional per-sentence fields; rejected for this refinement pass.

## Risks / Trade-offs

- [Content quality drift] → If the added 50 sentences are written inconsistently, the starter pack may feel uneven; mitigate by keeping topic groupings and tone aligned with the existing pack.
- [Label mismatch in old docs/tests] → Some current docs and tests still mention `Workplace sentences`; mitigate by updating only user-facing labels and the report/spec notes that matter most.
- [Accented Vietnamese typos] → Adding diacritics manually can introduce mistakes; mitigate by review before finalizing the asset.
- [Asset size growth] → Increasing the starter pack raises the bundled JSON size; mitigate by keeping sentence entries compact and reusing the same asset structure.
