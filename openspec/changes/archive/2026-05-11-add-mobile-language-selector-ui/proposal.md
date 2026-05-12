## Why

The mobile app already tracks an active learning language, but the learning screen does not give users a clear, visible place to see or change that language. This makes multi-language study harder to discover and increases the risk of users studying in the wrong language context without realizing it.

## What Changes

- Add a visible language selector to the mobile learning experience so users can see the active study language at a glance.
- Allow users to switch the active learning language directly from the interface without leaving the primary study flow.
- Ensure a language change updates the session context, reloads learning content for the selected language, and keeps proficiency labels aligned with that language's native scale.
- Persist the selected language so the app restores the same learning context when the user returns.

## Capabilities

### New Capabilities

- `mobile-language-selector`: Covers visible language selection controls and interaction rules in the mobile app.

### Modified Capabilities

- `mobile-learning-session`: Update learning-session requirements so the primary study surface exposes and responds to the active language selection state.

## Impact

- Affected mobile UI: learning screen header or primary action area, session controller, and persisted session preferences.
- Affected mobile data flow: card loading, recent review loading, and proficiency retrieval must follow the selected language after a switch.
- No backend API contract changes are required if the existing target-language parameters continue to be used.