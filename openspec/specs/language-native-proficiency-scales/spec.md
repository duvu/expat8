## Purpose
Define how the system resolves language-specific proficiency profiles from a registry keyed by target language.

## Requirements

### Requirement: System defines language-native proficiency profiles
The system SHALL resolve proficiency behavior from a language profile registry keyed by target language.

#### Scenario: English profile is resolved
- **WHEN** the active learning language is English
- **THEN** the system resolves the CEFR profile with ordered levels A1 through C2

#### Scenario: Chinese profile is resolved
- **WHEN** the active learning language is Chinese
- **THEN** the system resolves the HSK profile with ordered levels HSK1 through HSK6

### Requirement: Proficiency contract includes scale and ordered level
The system SHALL represent proficiency as `scale`, `level`, and `level_index` across API and internal state.

#### Scenario: Proficiency is returned to client
- **WHEN** a client requests proficiency or submits study events
- **THEN** the response includes `proficiency.scale`, `proficiency.level`, and `proficiency.level_index`

#### Scenario: Proficiency state is consumed by selection flow
- **WHEN** the backend selects next words for a learner
- **THEN** selection uses the provided `scale` and `level` pair instead of level-only assumptions

### Requirement: Progression and fallback are scale-scoped
The system SHALL apply increment, decrement, and fallback operations only within the active proficiency scale.

#### Scenario: User progresses in Chinese
- **WHEN** a Chinese learner reaches progression threshold from HSK2
- **THEN** the system advances proficiency to HSK3 and does not map through CEFR

#### Scenario: Fallback words are selected in Chinese
- **WHEN** no words exist at the learner's exact Chinese level
- **THEN** fallback checks adjacent levels only within the HSK profile order

### Requirement: Proficiency states are isolated by language
The system SHALL keep independent proficiency states per learner identity and language.

#### Scenario: User has both English and Chinese histories
- **WHEN** the same learner studies English and Chinese
- **THEN** the system stores and returns separate proficiency states for each language

#### Scenario: Client switches active language
- **WHEN** mobile changes active learning language from English to Chinese
- **THEN** subsequent requests use the Chinese proficiency state and scale metadata