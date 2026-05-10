## ADDED Requirements

### Requirement: Fallback vocabulary stubs are never auto-approved
When the enrichment pipeline falls back to generating stub vocabulary items (due to LLM unavailability or failure), those stubs SHALL be persisted with `approved = false` regardless of the article's upload source (including admin-uploaded articles). Admin review is required before stubs are served to learners.

#### Scenario: LLM enrichment fails and fallback stubs are generated
- **WHEN** LLM enrichment fails and `#fallbackSuggestions` produces stub vocabulary
- **THEN** each stub is persisted with `approved = false`

#### Scenario: Admin-uploaded article uses fallback stubs
- **WHEN** an admin uploads an article and enrichment falls back to stubs
- **THEN** the stubs are NOT auto-approved; they remain `pending_review` until an admin explicitly approves them

#### Scenario: LLM-enriched vocabulary for admin article is auto-approved
- **WHEN** an admin uploads an article and LLM enrichment succeeds (non-stub items)
- **THEN** the vocabulary items are auto-approved as before (no change to existing behavior)

### Requirement: Fallback stubs are identifiable as stubs
The enrichment pipeline SHALL mark stub vocabulary items so that downstream persistence logic can distinguish them from LLM-generated items.

#### Scenario: Stub item reaches persistence
- **WHEN** a stub vocabulary item produced by `#fallbackSuggestions` reaches `persistArticleVocabulary`
- **THEN** the item carries a `isStub: true` marker that the persistence layer can inspect
