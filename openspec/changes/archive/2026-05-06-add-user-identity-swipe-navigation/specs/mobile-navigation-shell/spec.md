## ADDED Requirements

### Requirement: Mobile app provides a left drawer menu
The mobile app SHALL provide a left-side drawer menu from the primary scaffold.

#### Scenario: Learner opens the drawer
- **WHEN** the learner opens the drawer from the Vocabulary screen
- **THEN** the app displays the navigation menu from the left side

### Requirement: Drawer contains Vocabulary navigation
The drawer SHALL include a `Vocabulary` navigation item that opens the vocabulary learning screen.

#### Scenario: Learner selects Vocabulary
- **WHEN** the learner taps `Vocabulary` in the drawer
- **THEN** the app shows the vocabulary learning screen and closes the drawer

### Requirement: Drawer shows identity action at the bottom
The drawer SHALL show `Sign in` at the bottom when signed out and `Sign out` at the bottom when signed in.

#### Scenario: Signed-out learner sees Sign in
- **WHEN** no user session is active
- **THEN** the drawer bottom action is `Sign in`

#### Scenario: Signed-in learner sees Sign out
- **WHEN** a user session is active
- **THEN** the drawer bottom action is `Sign out`
