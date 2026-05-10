## Context

The backend already exposes signed article CRUD endpoints for authenticated users: `POST /v1/articles`, `GET /v1/articles`, `GET /v1/articles/:id`, `GET /v1/articles/:id/vocabulary`, and `DELETE /v1/articles/:id`. Article creation accepts `title`, `language`, `raw_text`, optional `source_url`, and optional `visibility`; list/detail responses already include `status`, `processing_error`, and timestamps. The mobile app has a drawer-based navigation shell in `learning_screen.dart`, but no article management UI yet.

## Goals / Non-Goals

**Goals:**
- Let signed-in users create articles from raw text.
- Let users list their own articles and inspect processing status.
- Show article detail, processing errors, and extracted vocabulary.
- Allow owners to delete their own articles from mobile.
- Reuse the existing signed backend article APIs and session flow.

**Non-Goals:**
- File uploads, OCR, camera import, or clipboard automation.
- Editing article content after creation.
- Admin article moderation tooling.
- Changing backend article contracts in this change.

## Decisions

### Decision: Add a dedicated article area under the existing drawer navigation
Use the existing learning-screen drawer as the entry point to a new article management flow. This keeps the feature discoverable without changing the app's top-level navigation model.

Alternatives considered:
- App-bar action: rejected because article management is a secondary workflow and the shell already uses a drawer.
- Separate bottom tab: rejected because it would require broader navigation changes.

### Decision: Keep article creation text-first and minimal
Expose only the fields the backend already accepts and make `raw_text` the primary input. `source_url` and `visibility` can be optional advanced fields, but no non-text import flow should be implied.

Alternatives considered:
- Media/file picker upload: rejected because the backend contract and user need are centered on pasted text.
- Auto-extract metadata from URL: rejected because that would add unsupported behavior.

### Decision: Surface processing state directly in list and detail views
Show `status` and `processing_error` in the list and detail screens so users can see whether an article is pending, processing, processed, published, or failed without refreshing elsewhere.

Alternatives considered:
- Hide processing until detail view: rejected because users need immediate feedback after creating an article.

### Decision: Reuse the existing authenticated request flow
Article requests should use the same signed-session transport as other `/v1/*` mobile requests, including `Authorization: Bearer <session_token>` when signed in. This avoids creating a separate article transport path.

Alternatives considered:
- Anonymous article drafts: rejected because article management is explicitly for registered users.

## Risks / Trade-offs

- [Long article bodies can be awkward on mobile forms] -> Mitigate with a large multiline input and clear validation messaging.
- [Processing state may change while the user is browsing] -> Mitigate by refreshing the article list and detail after create/delete and on screen focus.
- [Delete is irreversible from the user's perspective] -> Mitigate with a confirmation dialog and only show the action on owned articles.
- [Vocabulary extraction may lag behind creation] -> Mitigate by showing `processing` and empty-state guidance until results exist.
