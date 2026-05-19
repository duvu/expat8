## ADDED Requirements

### Requirement: Vocabulary topic coverage is visualized
The dashboard SHALL provide a content coverage page showing word count by topic and language.

#### Scenario: Topic distribution chart is displayed
- **WHEN** an operator navigates to the content coverage page
- **THEN** a bar chart shows word count grouped by topic

### Requirement: Entry type distribution is shown
The dashboard SHALL show the distribution of vocabulary entry types (word, phrase, idiom).

#### Scenario: Entry type breakdown is visible
- **WHEN** an operator views the content coverage page
- **THEN** a pie chart shows the proportion of each entry type

### Requirement: Quality score distribution is tracked
The dashboard SHALL show a histogram of word_sense quality scores to identify content quality trends.

#### Scenario: Quality score histogram is displayed
- **WHEN** an operator views the content coverage page
- **THEN** a histogram shows the distribution of quality_score values across all word senses

### Requirement: Vocabulary review throughput is charted
The dashboard SHALL show daily approved/rejected vocabulary items over time.

#### Scenario: Review throughput chart is displayed
- **WHEN** an operator views the content coverage page
- **THEN** a stacked bar chart shows daily approved and rejected counts
