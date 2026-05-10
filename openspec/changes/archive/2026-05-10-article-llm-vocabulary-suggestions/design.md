## Context

The current worker flow extracts local token candidates first and then enriches each item individually with the LLM. That works for small, clean inputs, but it is a poor fit for long articles and phrase-level suggestions because the worker has to serialize too much logic around single tokens and a generic enrichment prompt.

We want the worker to treat the LLM as the main suggestion engine for article vocabulary, while still keeping backend validation and persistence authoritative. Long articles need chunking so the model can work on smaller contexts and return bounded outputs.

## Goals / Non-Goals

**Goals:**
- Use the LLM to suggest words and phrases directly from article text.
- Split long articles into manageable chunks before prompting the model.
- Capture suggestion classification and level on each returned item.
- Keep persistence gated by existing backend validation rules.

**Non-Goals:**
- Change the article upload API or dashboard workflow.
- Replace the article job queue or worker deployment model.
- Remove the existing validation layer or persistence schema.
- Introduce a separate external queue system.

## Decisions

### Decision 1: Move from token-first enrichment to chunk-first LLM suggestion

The worker should ask the LLM to suggest candidate words and phrases for each chunk instead of only enriching preselected tokens.

**Rationale:** The user wants phrase suggestions and classification/level output. A chunk-first prompt gives the model enough context to surface multiword expressions and learning-grade suggestions.

**Alternatives considered:**
- Keep token-first enrichment and add phrase heuristics around it. Rejected because it still biases the worker toward local token extraction.
- Ask the LLM once for the whole article. Rejected because long articles become unstable and prompt limits are harder to manage.

### Decision 2: Chunk long articles deterministically before LLM calls

The worker should split article text into bounded chunks using a deterministic rule based on text length and paragraph/sentence boundaries when available.

**Rationale:** Deterministic chunking makes behavior reproducible and keeps very long articles from exceeding model limits or becoming too costly.

**Alternatives considered:**
- Dynamic chunk sizing based on model feedback. Rejected as too complex for the initial rollout.
- Fixed token-count chunking only. Rejected because it makes implementation more brittle and less readable than a length/boundary-aware split.

### Decision 3: Preserve validation and persistence as separate backend steps

The worker can suggest items, but backend validation still decides what gets persisted.

**Rationale:** The backend already enforces schema and quality checks. Keeping that gate avoids storing malformed or low-quality suggestions.

**Alternatives considered:**
- Trust LLM output directly. Rejected because it would weaken data quality guarantees.

### Decision 4: Surface classification and level in the article vocabulary response

Article vocabulary reads should expose suggestion metadata such as classification and level where available.

**Rationale:** The suggestion engine becomes more useful when downstream consumers can see how and why an item was suggested. That metadata also helps review workflows and debugging.

**Alternatives considered:**
- Hide the new metadata in storage only. Rejected because it would make review and QA harder.

## Risks / Trade-offs

- **[Risk]** Chunking may duplicate similar suggestions across chunks. → **Mitigation:** dedupe suggestions before persistence and keep normalized-term conflict handling.
- **[Risk]** LLM suggestion output may be noisier than token-first enrichment. → **Mitigation:** maintain strict validation and reject weak or malformed items.
- **[Risk]** Longer LLM prompts may increase cost and latency. → **Mitigation:** bound chunk size, keep prompts structured, and cap output per chunk.
- **[Risk]** Response-shape changes may require dashboard/API consumers to adapt. → **Mitigation:** preserve existing fields and only add optional metadata.

## Migration Plan

1. Introduce chunking and LLM suggestion prompts in the worker pipeline.
2. Extend persistence and read paths to carry classification/level metadata.
3. Run worker smoke tests with short and long articles.
4. Verify article vocabulary still resolves correctly for published/private access patterns.
5. Roll back by disabling the LLM suggestion path and falling back to the existing candidate extraction/enrichment flow if needed.

## Open Questions

- What is the preferred chunk boundary policy: character count, sentence count, or approximate token count?
- Should phrase suggestions be stored as a distinct suggestion type or inferred from term length/structure?
- Do we need a worker config knob for max suggestions per chunk and max chunks per article?
