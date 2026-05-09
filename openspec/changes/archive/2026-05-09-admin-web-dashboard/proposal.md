## Why

The backend already supports article ingestion, async processing, admin review, and publish actions, but there is no browser workflow that lets content editors actually use that pipeline end to end. We need an admin dashboard now so article upload, vocabulary review, and publish decisions happen through one clear web surface instead of ad hoc API usage.

## What Changes

- Add a browser-based admin dashboard for article upload, processing tracking, vocabulary review, and publish actions.
- Add dashboard flows for pasting raw article text or importing an article source, then submitting it to the backend for processing.
- Add article list and review views that surface backend processing state, extracted vocabulary, and review decisions.
- Add vocabulary review actions for approve, reject, and review-note updates so admins can govern extracted terms and phrases before publication.
- Add server-side article and vocabulary reads in the dashboard so it can render detail and review views without needing new backend read endpoints first.
- Keep LLM generation in the backend worker path; the dashboard only orchestrates backend workflow and displays results.

## Capabilities

### New Capabilities
- `admin-web-dashboard`: Browser-based article upload, review, and publish workflow for content editors and reviewers.

### Modified Capabilities
- None

## Impact

- Frontend: new web admin application and shared API client for browser use.
- Backend: reuse existing admin article and vocabulary review endpoints; no new generation logic in the browser.
- Auth/security: dashboard must work with the existing admin token and app-credential model for `/v1/*` requests.
- Operations: adds a new browser deployment surface for content operations and review workflows.
