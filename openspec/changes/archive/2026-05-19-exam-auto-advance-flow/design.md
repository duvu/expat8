## Context

The current exam flow is split between a topic selector, a question screen with a Next button, and a results screen. The backend also keys session creation on a topic string. This change removes topic selection from the user-visible flow and makes the exam feel like a single continuous progression driven by answer taps.

## Goals / Non-Goals

**Goals:**
- Start exams directly from the active learning language
- Advance questions on answer selection without a Next button
- Submit automatically after the last answer and show results immediately after commit
- Keep the backend scoring contract intact

**Non-Goals:**
- Redesigning the results screen
- Changing exam scoring or certificate rules
- Adding offline exam submission
- Introducing a new persistence model

## Decisions

### 1. Keep the backend session contract language-scoped, not topic-scoped
The backend already builds exam sessions from studied words and can determine eligibility from the user's language-specific corpus. Removing topic selection from the mobile flow means the backend should treat language as the primary selector for the session.

Alternative considered: keep topic selection hidden in the UI. Rejected because the user explicitly wants no topic splitting and the topic concept adds unnecessary friction.

### 2. Move auto-advance into the question screen controller flow
Answer selection should call the controller's existing answer-commit path and then immediately advance. The controller remains the source of truth for answer ordering and submission timing.

Alternative considered: let the results screen poll for completion. Rejected because the question screen already owns answer entry and progression, and polling would add complexity.

### 3. Show results only after the submit response resolves
The last answer should trigger submission, and the app should wait for the backend response before navigating to results. This keeps the visible state aligned with the committed attempt and avoids premature results rendering.

Alternative considered: render a local provisional results view immediately after the last tap. Rejected because it would diverge from the backend-scored result and complicate error handling.

### 4. Remove the topic selector from the primary exam path
The learning screen can enter exam mode directly for the active language. This preserves the app's current exam entry point while removing a step the user no longer wants.

Alternative considered: keep the topic screen as an optional advanced mode. Rejected because the request is specifically to stop splitting exams into topics.

## Risks / Trade-offs

- [Risk] Existing topic-based data is still stored in backend records. → Keep the stored topic field for historical compatibility, but stop relying on it for user entry.
- [Risk] The UI may still need a loading state while submit resolves. → Keep the existing submitting state and navigate to results only after success.
- [Risk] Answer-tap auto-advance can hide mistakes if state updates lag. → Rely on the controller's single-commit-per-question behavior and existing listener flow.

## Migration Plan

1. Update the mobile entry path to start exams directly from the learning screen.
2. Change the question screen so a choice tap commits the answer and advances immediately.
3. Remove the Next button and any topic-picking UI from the primary exam path.
4. Update backend exam session generation and response docs to reflect language-scoped start behavior.
5. Verify with widget tests and backend tests that question order, submission, and results all remain correct.

## Open Questions

- Should the backend continue returning `topic` in exam responses for historical display, even though the UI no longer asks the user to choose one?
