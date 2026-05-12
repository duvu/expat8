## Context

The mobile app already passes a target language through session-driven API calls, and the learning-session controller keeps an internal `_activeLearningLanguage` state. Today that state starts at `'en'`, is updated indirectly from fetched proficiency, and is not exposed as a clear user-controlled setting on the learning screen. The app also already has lightweight key/value persistence through `LocalDatabase.app_settings`, which is the lowest-friction place to store a preferred learning language.

## Goals / Non-Goals

**Goals:**
- Make the active study language visible on the primary learning surface.
- Let users change the active language without leaving the learning flow.
- Persist the selected language locally and restore it on next app launch.
- Ensure card loading, review loading, and proficiency fetching all use the newly selected language immediately after a switch.
- Keep the UI compatible with language-native proficiency labels already returned by the backend.

**Non-Goals:**
- Adding new backend endpoints or changing existing API contracts.
- Introducing remote account-level preference sync for language selection.
- Designing a full settings screen or multi-preference management surface.
- Expanding the set of supported learning languages beyond what the app/backend already support.

## Decisions

### Decision: Use an inline selector on the learning screen
Place a dedicated language selector in a prominent position near the top of the learning screen rather than hiding language selection in the drawer. This keeps the control visible during the study flow and satisfies the requirement that the selector be easy to notice.

Alternatives considered:
- Drawer-only selector: rejected because it is discoverable only after opening navigation and is too indirect for a session-level control.
- App-bar overflow action: rejected because it reduces visibility and makes the active language easy to miss.

### Decision: Reuse local app settings for persistence
Store the active learning language in `LocalDatabase.app_settings` using a dedicated key, and have the repository/controller read it during startup. This avoids schema expansion beyond the existing settings mechanism and keeps the preference local to the device, matching current session state behavior.

Alternatives considered:
- Keep the value only in memory: rejected because the selection would be lost on restart.
- Persist as part of the user session object: rejected because the preference must also work for signed-out users and does not belong to authentication state.

### Decision: Treat language switching as a session reset-and-reload event
When the user switches language, clear the current card presentation state that depends on the previous language, fetch proficiency for the new language, and then load the next card using the new language. This keeps the controller behavior coherent and prevents mixed-language cards or mismatched proficiency labels.

Alternatives considered:
- Lazily apply the new language on the next swipe: rejected because the UI could display stale language state after the user thinks the change is complete.
- Preserve the existing card until rated: rejected because it makes the session state ambiguous after a language switch.

### Decision: Keep the source of truth in the learning-session controller
The controller already coordinates loading, rating, proficiency updates, and feedback messages. Extending it with explicit `activeLearningLanguage` accessors and a `setActiveLearningLanguage(...)` flow keeps UI logic thin and ensures all downstream repository calls stay aligned.

Alternatives considered:
- Let the widget manage selected language independently: rejected because it risks desynchronizing the UI from repository and proficiency state.

## Risks / Trade-offs

- [Language switch interrupts the current study moment] → Mitigate by making the selector explicit and immediately reloading the session so the state change is predictable.
- [Persisted language becomes invalid if supported languages change] → Mitigate by validating restored values against the app's supported-language list and falling back to a default.
- [Additional UI chrome can crowd the top of the screen] → Mitigate by keeping the selector compact but visually distinct, with large tap targets in the chooser surface.
- [Local review/new-card stores may contain mixed languages] → Mitigate by filtering or re-querying through the existing language-aware repository paths rather than reusing the previous visible card.