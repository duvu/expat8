# dashboard-speaking-analytics Specification

## Purpose
Define the speaking analytics page of the admin dashboard, providing operators with speaking event volume trends, self-rating distribution, drill completion metrics, and prompt coverage measurement.

## Requirements

### Requirement: Speaking event volume is visualized over time
The dashboard SHALL provide a speaking analytics page showing daily speaking event volume as a time-series chart, broken down by event type.

#### Scenario: Speaking event trend is displayed
- **WHEN** an operator navigates to the speaking analytics page
- **THEN** a line chart shows daily speaking events for the selected time range

### Requirement: Self-rating distribution is shown
The dashboard SHALL display the distribution of speaking self-ratings (clear, hesitated, could_not_say) as a chart.

#### Scenario: Self-rating breakdown is visible
- **WHEN** an operator views the speaking analytics page
- **THEN** a pie/donut chart shows the proportion of each self-rating value

### Requirement: Drill completion metrics are computed
The dashboard SHALL show drill completion rate (completed drills / started drills) and average recording duration.

#### Scenario: Drill completion rate is displayed
- **WHEN** an operator views the speaking analytics page
- **THEN** KPI cards show the drill completion rate and average recording duration

### Requirement: Speaking prompt coverage is measured
The dashboard SHALL show how many word senses have approved speaking prompts vs. total word senses available.

#### Scenario: Prompt coverage metric is visible
- **WHEN** an operator views the speaking analytics page
- **THEN** a coverage metric shows X approved prompts / Y total word senses with a percentage
