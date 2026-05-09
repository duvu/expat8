---
name: simplify-codebase
description: Use this skill when simplifying, refactoring, modularizing, reducing duplication, improving reuse, improving code quality, or improving efficiency in an existing codebase without changing behavior.
compatibility: opencode
metadata:
  category: refactoring
  risk: medium
---

# Simplify Codebase Skill

## Purpose

Use this skill when the user asks to simplify, clean up, refactor, modularize, improve reuse, improve code quality, improve maintainability, or improve efficiency in an existing codebase.

The goal is not to rewrite the system. The goal is to make the smallest safe improvements that reduce complexity, improve reuse, improve testability, and preserve existing behavior.

## Non-negotiable rules

1. Preserve existing behavior unless the user explicitly asks for behavior changes.
2. Do not perform large rewrites.
3. Do not edit files before producing a simplification plan.
4. Use Serena, symbol search, LSP, or targeted search before reading full files.
5. Do not read the whole repository unless necessary.
6. Do not modify migrations, secrets, `.env`, production config, CI/CD config, or deployment files unless explicitly requested.
7. Do not introduce new dependencies unless clearly justified.
8. Do not create generic abstractions for one use case.
9. After editing, show the diff summary and run relevant tests.
10. If tests cannot be run, explain why and list the exact tests the user should run.

## What to optimize for

Optimize for:

- Simpler control flow
- Smaller functions/classes
- Clearer responsibility boundaries
- Less duplicate logic
- Better reuse where reuse is justified
- Better names
- Better testability
- Fewer hidden side effects
- Lower coupling
- Better error handling consistency
- Better validation consistency
- More efficient data access when evidence exists

Do not optimize for cleverness.

## Problem classification

Classify the target issue as one or more of:

- Duplicate logic
- Large method
- Large class
- Mixed responsibilities
- Hard-coded business rules
- Repeated mapping/conversion logic
- Repeated validation logic
- Inconsistent error handling
- Inconsistent naming
- Excessive coupling
- Poor testability
- Dead code
- Inefficient database access
- Inefficient loop
- Repeated remote API call
- Over-engineered abstraction
- Leaky abstraction

## Workflow

### Step 1: Inspect safely

Before editing:

1. Identify the target module or feature.
2. Inspect project structure.
3. Use Serena or symbol search first.
4. Identify affected classes/functions/tests.
5. Read only relevant files.

### Step 2: Produce a simplification plan

Before editing, return:

## Simplification Plan

- Target area:
- Current problem:
- Evidence from code:
- Proposed simplification:
- Files likely affected:
- Behavior impact:
- Risk level: low / medium / high
- Tests to run:
- Rollback notes:

## Decision

- Proceed / do not proceed:
- Reason:

Do not edit files until the plan is clear.

### Step 3: Apply minimal changes

When allowed to edit:

1. Change only necessary files.
2. Prefer extracting small private methods before introducing new classes.
3. Prefer composition over inheritance.
4. Prefer explicit domain names over generic utility names.
5. Keep API contracts stable.
6. Keep database schema unchanged unless explicitly requested.
7. Keep public method behavior unchanged unless explicitly requested.
8. Add or update tests when behavior could be affected.

### Step 4: Validate

After editing, return:

## Changes Made

- Files changed:
- Summary:
- Reuse improvement:
- Quality improvement:
- Efficiency improvement:
- Behavior impact:
- Tests run:
- Test result:
- Remaining recommendations:

## Java / Spring Boot guidance

For Java Spring Boot projects:

- Controllers should stay thin.
- Business logic belongs in service classes.
- Repositories should not contain business logic.
- DTOs should be used at API boundaries.
- Avoid exposing JPA entities directly in API responses.
- Keep exception handling consistent with the existing global exception handler.
- Keep validation consistent with existing request DTO validation.
- Use transactions only where state changes must be atomic.
- Avoid circular dependencies between services.
- Avoid utility classes unless there are at least two real call sites.
- Prefer local helper methods when reuse is local.
- Prefer domain-specific names over vague names like `CommonUtil`, `Helper`, or `Manager`.

## Efficiency checklist

Look for:

- Repeated database calls in loops
- N+1 query risks
- Repeated remote API calls
- Loading more data than needed
- Repeated parsing or serialization
- Repeated object mapping
- Unnecessary full collection scans
- Blocking I/O in hot paths
- Repeated expensive computation

Do not add caching unless cache invalidation, consistency, and memory impact are clear.

## Reuse checklist

Good reuse:

- Same business rule duplicated in multiple places
- Same validation repeated
- Same mapping logic repeated
- Same external API handling repeated
- Same error handling pattern repeated

Bad reuse:

- Abstracting code only because it looks similar
- Creating generic frameworks for one use case
- Moving domain-specific logic into vague utility classes
- Hiding business meaning behind generic names
- Introducing inheritance when composition is enough
