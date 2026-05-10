## Why

Registered users can study vocabulary today, but they cannot yet create or manage their own article sources from the mobile app. We need a mobile flow for adding article text, tracking processing status, and removing articles the user no longer wants while reusing the existing signed article APIs.

## What Changes

- Add an article management area in the mobile app for signed-in users.
- Add an article create/upload flow that submits title, raw text, language, and optional source URL.
- Add article list and detail views showing processing status, errors, and extracted vocabulary.
- Add owner-only delete actions from mobile.
- Reuse the existing authenticated backend article endpoints and signed request flow.
- Non-goal: file-based uploads, OCR/import pipelines, or editing article text after creation.

## Capabilities

### New Capabilities
- `mobile-article-management`: registered users can create, list, inspect, and delete their own articles from the mobile app.

### Modified Capabilities

## Impact

- Mobile navigation, repository/API client layer, and new article list/detail/create screens.
- Article-related request signing and authenticated session handling in the Flutter app.
- End-to-end article UX for creating content, reviewing processing status, and deleting articles.
- Mobile tests covering article CRUD and state refresh behavior.
