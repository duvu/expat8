## Why

The sentence study feature works, but the current surface still says `Workplace sentences`, which is too verbose for the main drawer entry and screen title. The bundled starter set also needs a content refresh: add 50 more sentences and fix Vietnamese meanings so they read naturally with proper diacritics.

## What Changes

- Rename the visible app entry point from `Workplace sentences` to `Sentences`.
- Update the sentence study screen title and related UI copy to use the shorter label.
- Expand the bundled starter pack from 100 to 150 sentences.
- Normalize bundled Vietnamese meanings to use proper accents/diacritics.
- Add a markdown review report that summarizes what is complete and what remains open for the sentence feature refinement.

## Capabilities

### New Capabilities
- `review-report`: markdown review output for completed vs remaining sentence-work items.

### Modified Capabilities
- `mobile-workplace-sentence-session`: change the visible entry label to `Sentences`, expand the bundled starter set, and improve bundled Vietnamese copy quality.

## Impact

- Mobile UI labels in the learning drawer and workplace sentence screen.
- Bundled asset content at `mobile/assets/seed_workplace_sentences/en.json`.
- Sentence seed/import tests and UI expectations.
- OpenSpec review notes and implementation checklist for the change.
