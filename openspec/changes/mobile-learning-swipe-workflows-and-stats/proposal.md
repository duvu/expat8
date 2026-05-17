## Why

The current mobile learning flow does not apply one consistent swipe model across vocabulary and sentence screens, and learners have no clear way to replay recent items or inspect their own progress. This change standardizes the gesture interaction model and adds a lightweight progress surface so the learning experience is easier to understand and maintain.

## What Changes

- Standardize four-direction swipe behavior across all mobile learning screens, including vocabulary and workplace sentence flows.
- Right-to-left swipe marks the current item as learned and advances to the next card using the shared 15% new / 85% re-learned selection policy.
- Left-to-right swipe opens an ordered history view of items previously learned through right-to-left swipes.
- Bottom-to-top swipe marks the current item as remembered and removes it from further relearning.
- Top-to-bottom swipe marks the current item as difficult and schedules it for relearning later.
- Add a user-facing statistics page that shows totals for learned, remembered, and difficult items.
- Keep the interaction model local-first so the learning flow still works without introducing new backend round-trips.

## Capabilities

### New Capabilities
- `mobile-learning-history-view`: Ordered replay/history view for recently learned items, preserving the sequence created by learning swipes.
- `mobile-learning-progress-stats`: Learner-facing stats page showing learned, remembered, and difficult totals.

### Modified Capabilities
- `mobile-gesture-learning-controls`: Update swipe-direction semantics and intent mapping for all learning screens.
- `mobile-learning-session`: Apply the shared swipe workflow and selection policy to the vocabulary learning session.
- `mobile-workplace-sentence-session`: Apply the same swipe workflow and history behavior to sentence learning.
- `mobile-offline-first-learning`: Persist the new learning states and history locally before any sync attempt.

## Impact

- Mobile UI: learning screens gain consistent swipe behavior, a history replay surface, and a new stats page.
- Mobile state/data: local persistence needs to track learned, remembered, difficult, and history ordering.
- Learning flow: vocabulary and sentence sessions must use the same interaction rules so behavior stays consistent across entry points.
- Backend/API: no contract changes are expected unless a later sync requirement is introduced for progress data.
