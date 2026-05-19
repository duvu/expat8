# dashboard-pipeline-monitor Specification

## Purpose
Define the pipeline monitor page of the admin dashboard, giving operators visibility into article processing status, queue depth, job duration metrics, and word generation run history.

## Requirements

### Requirement: Article processing pipeline status is visible
The dashboard SHALL provide a pipeline monitor page showing article status funnel, processing queue depth, and job failure rate.

#### Scenario: Article status funnel is displayed
- **WHEN** an operator navigates to the pipeline monitor page
- **THEN** a funnel or bar chart shows article counts by status (pending_processing, processing, processed, published, failed)

#### Scenario: Queue depth is shown as a gauge
- **WHEN** an operator views the pipeline monitor
- **THEN** a KPI card shows the current count of unprocessed jobs in the queue

### Requirement: Processing job duration metrics are tracked
The dashboard SHALL show p50 and p95 processing duration for completed jobs over the selected time range.

#### Scenario: Duration metrics are visible
- **WHEN** an operator views the pipeline monitor
- **THEN** KPI cards show p50 and p95 job processing time in seconds

### Requirement: Word generation run history is visible
The dashboard SHALL show generation run history including status, requested vs. inserted counts, timing, and error messages.

#### Scenario: Generation runs table is displayed
- **WHEN** an operator views the generation section
- **THEN** a table shows recent generation runs with status, counts, duration, and any error messages

#### Scenario: Generation success rate is charted
- **WHEN** an operator views the generation section
- **THEN** a bar chart shows successful vs. failed runs over time
