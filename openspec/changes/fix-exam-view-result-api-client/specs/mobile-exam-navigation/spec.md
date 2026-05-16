## MODIFIED Requirements

### Requirement: Results navigation matches language-only exam flow
The mobile exam results navigation SHALL assume the current direct exam flow, where the question route is replaced by the results route and no topic-picker route exists beneath results. Result actions MUST retain all runtime dependencies needed by routes they open.

#### Scenario: No topic route is present
- **WHEN** the exam results screen is shown after the final answer
- **THEN** results actions MUST NOT require a topic-picker route to exist in the navigator stack

#### Scenario: View Certificate keeps API client dependency
- **WHEN** a passed exam result includes a certificate ID and the user taps `View Certificate`
- **THEN** the certificate route receives a usable API client and does not show `API client not available.`
