## ADDED Requirements

### Requirement: Dashboard renders a fixed left sidebar on every page
The system SHALL render a single left sidebar component that is present on every dashboard page, listing navigation links to all sections.

#### Scenario: Sidebar is visible on the home page
- **WHEN** an admin loads any dashboard route
- **THEN** a left sidebar is visible containing navigation links to Articles, New Article, Vocabulary Review, Speaking Prompts, Exam Results, and Users

#### Scenario: Active route is highlighted in the sidebar
- **WHEN** the admin is on the `/review` route
- **THEN** the "Vocabulary Review" sidebar link is visually distinguished as the active item, and all other links are in the default state

#### Scenario: Sidebar is present on nested routes
- **WHEN** the admin navigates to `/articles/[id]` or `/users/[id]`
- **THEN** the sidebar remains visible with the correct parent section highlighted

### Requirement: Dashboard renders a persistent top toolbar on every page
The system SHALL render a single top toolbar that displays the current page title and an optional action slot.

#### Scenario: Toolbar shows the current page title
- **WHEN** an admin navigates to the Users section
- **THEN** the toolbar title reads "Users"

#### Scenario: Toolbar renders page-level actions when supplied
- **WHEN** a page provides a toolbar action (e.g. a "New article" button on the home page)
- **THEN** the action is rendered in the right side of the toolbar

#### Scenario: Toolbar title changes on navigation
- **WHEN** an admin navigates from Articles to Exam Results
- **THEN** the toolbar title updates to "Exam Results"

### Requirement: Dashboard provides a PageShell component that each page uses to integrate with the shell
The system SHALL provide a `<PageShell>` component that accepts a `title` prop and an optional `actions` slot, and which renders the page content below the toolbar.

#### Scenario: PageShell supplies title to toolbar
- **WHEN** a page mounts `<PageShell title="Vocabulary Review">`
- **THEN** the toolbar displays "Vocabulary Review" as the page title

#### Scenario: PageShell renders children in the content area
- **WHEN** a page places content inside `<PageShell>`
- **THEN** the content appears in the scrollable area below the toolbar and to the right of the sidebar

### Requirement: Dashboard shell is responsive — sidebar collapses on small viewports
The system SHALL collapse the left sidebar on viewports ≤ 768 px and show a toggle control in the toolbar.

#### Scenario: Sidebar is hidden by default on small viewports
- **WHEN** the viewport width is 480 px and the page loads
- **THEN** the sidebar is not visible and a hamburger/menu icon is shown in the toolbar

#### Scenario: Tapping the toggle opens the sidebar on small viewports
- **WHEN** the admin taps the menu icon in the toolbar
- **THEN** the sidebar slides into view over the content area

#### Scenario: Tapping the toggle a second time closes the sidebar
- **WHEN** the sidebar is open on a small viewport and the admin taps the menu icon again
- **THEN** the sidebar is hidden
