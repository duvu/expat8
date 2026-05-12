## Purpose
Define how the backend requests vocabulary from the LLM in batches of 100 to maximise generation efficiency.

## ADDED Requirements

### Requirement: Backend generates vocabulary in batches of 100
The backend SHALL request exactly 100 vocabulary items per LLM call to maximise generation efficiency.

#### Scenario: LLM batch size is 100
- **WHEN** the backend determines that new vocabulary generation is needed
- **THEN** the backend requests 100 words in a single LLM call

#### Scenario: LLM returns fewer than 100 valid items
- **WHEN** the LLM returns fewer than 100 items that pass validation
- **THEN** the backend persists all valid items and does not fail; retry loop may issue additional calls to reach target

#### Scenario: Generated batch is stored
- **WHEN** a batch of generated vocabulary passes validation
- **THEN** the backend stores all accepted items in the word database for future serving
