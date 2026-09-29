# Adaptive Proficiency Migration Guide

## Scope

This guide covers migration from legacy difficulty labels to canonical proficiency levels used by adaptive progression.

## Legacy Difficulty Mapping

Use canonical mappings during ingest/backfill:

- beginner -> A1
- intermediate -> B1
- advanced -> C1

If finer mapping is needed in curated content:

- beginner-high -> A2
- intermediate-high -> B2
- advanced-high -> C2

## Data Backfill Steps

1. Add canonical difficulty_level where missing.
2. Normalize existing rows to canonical levels.
3. Keep legacy source value only as metadata if needed for audit.
4. Validate all rows are in the allowed set for each language scale.

## Validation Rules

English accepted levels:

- A1, A2, B1, B2, C1, C2

Chinese accepted levels:

- HSK1, HSK2, HSK3, HSK4, HSK5, HSK6

Reject or remap non-canonical values before persisting production content.

## Rollout Notes

- Deploy with compatibility mode additive during transition.
- Monitor proficiency distribution and fallback frequency.
- Move to strict mode once old clients and old payload assumptions are retired.
