## 1. Article Navigation and Entry Point

- [x] 1.1 Add an article management entry from the existing mobile drawer or equivalent navigation surface
- [x] 1.2 Add routing or screen wiring for article list, create, and detail views
- [x] 1.3 Add or update tests covering navigation into the article management flow

## 2. Article Create Flow

- [x] 2.1 Implement a text-first article create form for title, language, raw text, and optional source URL
- [x] 2.2 Wire the form to the authenticated article create endpoint and surface validation/error states
- [x] 2.3 Add or update tests covering article creation success and failure cases

## 3. Article List and Detail

- [x] 3.1 Implement an article list view showing article status, timestamps, and processing errors
- [x] 3.2 Implement an article detail view showing metadata and extracted vocabulary
- [x] 3.3 Refresh article state after create, delete, or manual reload so status changes are visible
- [x] 3.4 Add or update tests covering list refresh and detail loading behavior

## 4. Delete and Verification

- [x] 4.1 Add owner-only delete actions with confirmation and success feedback
- [x] 4.2 Prevent delete affordances for articles not owned by the current user
- [x] 4.3 Run the relevant mobile test suite for article management behavior
