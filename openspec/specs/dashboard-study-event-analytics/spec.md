# dashboard-study-event-analytics Specification

## Purpose
Define the study event analytics page of the admin dashboard, providing operators with event volume trends by rating, DAU/WAU/MAU metrics, and a filterable table of recent study events.

## Requirements

### Requirement: Study event trends are visualized over time
The dashboard SHALL provide a study events analytics page showing daily event volume as a time-series chart with rating breakdown (easy, too_easy, hard, too_hard).

#### Scenario: Rating distribution chart renders
- **WHEN** an operator navigates to the study events analytics page
- **THEN** a stacked area chart shows daily event counts broken down by rating type

### Requirement: Active learner metrics are computed
The dashboard SHALL display DAU (daily active users), WAU (weekly active users), and MAU (monthly active users) derived from distinct device_id/user_id in study_events.

#### Scenario: DAU/WAU/MAU metrics are displayed
- **WHEN** an operator views the study events page
- **THEN** KPI cards show today's DAU, this week's WAU, and this month's MAU

### Requirement: Study event table with filtering
The dashboard SHALL provide a filterable table of recent study events showing device_id, user_id, rating, language, occurred_at.

#### Scenario: Events can be filtered by date range and rating
- **WHEN** an operator applies filters for rating type and date range
- **THEN** the table shows only matching study events
