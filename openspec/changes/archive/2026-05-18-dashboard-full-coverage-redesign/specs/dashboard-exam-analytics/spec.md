## ADDED Requirements

### Requirement: Exam pass rate and score distribution are visualized
The dashboard SHALL provide an exam analytics page showing overall pass rate, score distribution histogram, and attempts over time.

#### Scenario: Pass rate gauge is displayed
- **WHEN** an operator navigates to the exam analytics page
- **THEN** a gauge or KPI card shows the overall pass rate percentage

#### Scenario: Score distribution is visible
- **WHEN** an operator views the exam analytics page
- **THEN** a histogram shows the distribution of exam scores (0-100%)

### Requirement: Exam results can be broken down by topic and language
The dashboard SHALL show pass rate and average score grouped by topic and language.

#### Scenario: Per-topic breakdown is visible
- **WHEN** an operator views the topic breakdown section
- **THEN** a grouped bar chart shows pass rate per topic

### Requirement: Most-missed words are identified
The dashboard SHALL identify the vocabulary words most frequently answered incorrectly in exams.

#### Scenario: Most-missed words list is shown
- **WHEN** an operator views the exam analytics page
- **THEN** a table shows the top 20 words with the lowest correct-answer rate across all exams
