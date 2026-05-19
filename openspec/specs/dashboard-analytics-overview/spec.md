# dashboard-analytics-overview Specification

## Purpose
Define the analytics overview section of the admin dashboard, providing operators with real-time KPI cards, time-series activity charts, and pipeline health summaries on the dashboard home page.

## Requirements

### Requirement: Dashboard home page displays real-time KPI cards
The dashboard home page SHALL display KPI cards showing: total users, active users (7d), total study events, study events today, exam pass rate, and speaking drill sessions this week.

#### Scenario: KPI cards load with current data
- **WHEN** an operator navigates to the dashboard home page
- **THEN** KPI cards display current aggregate values computed from the database

### Requirement: Dashboard home page displays time-series activity chart
The dashboard home page SHALL display a time-series chart showing daily study event volume and active unique learners over the selected time range.

#### Scenario: Activity chart renders with 30-day default
- **WHEN** an operator views the home page without selecting a time range
- **THEN** a line chart shows daily study events and active users for the past 30 days

#### Scenario: Time range can be changed
- **WHEN** an operator selects a different time range (7d, 30d, 90d)
- **THEN** the chart updates to show data for the selected period

### Requirement: Dashboard home page displays pipeline health summary
The dashboard home page SHALL show a summary of article processing pipeline health: pending jobs, failed jobs in last 24h, and average processing duration.

#### Scenario: Pipeline health is visible
- **WHEN** an operator views the home page
- **THEN** a pipeline status section shows pending job count, recent failure count, and p50 processing time
