## MODIFIED Requirements

### Requirement: Generated vocabulary is validated before persistence
The backend MUST validate AI-generated vocabulary before saving or serving it using language-profile aware pronunciation rules: English items require IPA, while Chinese items require pinyin and do not require IPA.

#### Scenario: Difficulty level is invalid for language profile
- **WHEN** a generated item includes a difficulty value that is not valid for the active language scale
- **THEN** the backend rejects that item

#### Scenario: English item has IPA pronunciation metadata
- **WHEN** a generated English item has non-empty `ipa` and all other required metadata is valid
- **THEN** the backend accepts the item pronunciation metadata

#### Scenario: English item has empty IPA
- **WHEN** a generated English item has empty `ipa`
- **THEN** the backend rejects that item before persistence with an IPA-specific rejection reason

#### Scenario: Chinese item has pinyin and no IPA
- **WHEN** a generated Chinese item has empty `ipa` and valid pinyin in the existing `vietnamese_pronunciation` pronunciation slot
- **THEN** the backend accepts the pronunciation metadata instead of rejecting the item as `missing_ipa`

#### Scenario: Chinese item lacks pinyin
- **WHEN** a generated Chinese item lacks valid pinyin in the existing `vietnamese_pronunciation` pronunciation slot
- **THEN** the backend rejects that item or flags it for regeneration with a pinyin-specific rejection reason

#### Scenario: Chinese item includes IPA but lacks pinyin
- **WHEN** a generated Chinese item includes `ipa` but lacks valid pinyin in the existing `vietnamese_pronunciation` pronunciation slot
- **THEN** the backend rejects that item because Chinese validation is based on pinyin, not IPA
