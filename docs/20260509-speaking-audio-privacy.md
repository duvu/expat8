# Expat8 Speaking Audio Privacy - Phase 0-3

## Purpose

This document captures the privacy constraints for the phase 0-3 speaking foundation. The product goal is to help Vietnamese learners start speaking out loud without creating unnecessary privacy or trust risk.

## Default Policy

Learner speaking audio is **local-only by default** during phase 0-3.

The app may store recordings on the learner's device so the learner can play back their own attempt, retry, and self-rate. The backend receives only non-audio metadata needed for sync and analytics.

## What May Be Synced

Allowed speaking event metadata:

- `attempt_id`
- `prompt_id`
- `word_sense_id` or `server_word_id`
- `duration_ms`
- `retry_count`
- `self_rating`: `clear`, `hesitated`, `could_not_say`, or `null`
- `event_type`
- `occurred_at`
- `language`
- `device_id`

## What Must Not Be Synced

Speaking event sync MUST NOT include:

- Raw audio bytes.
- Base64-encoded audio.
- Local audio file paths.
- Microphone device identifiers.
- Any transcript generated from private audio unless a future explicit opt-in flow is introduced.

## User Controls

The mobile app should provide:

- Clear copy that recordings stay on the device in this phase.
- Delete-one-recording control for an individual attempt.
- Delete-all-local-speaking-recordings control.
- Recovery path when microphone permission is denied.

## Retention

Local recordings should be bounded by a configurable retention window. Phase 0-3 defaults to a short retention policy so old recordings can be cleaned up without a backend request.

## Operational Notes

- Backend, dashboard, and mobile logs must not include raw audio or local file paths.
- API contracts should continue to describe speaking sync as metadata-only.
- Any future AI pronunciation scoring that uploads audio must introduce a separate opt-in, retention, deletion, and security review.
