// User-submitted word rules shared by both stores.

import { createId } from '../ids.js';
import { normalizeTerm } from '../normalize.js';

export function submittedWordFailureReason(error) {
  const message = error?.message ?? error;
  return String(message || 'generation_failed');
}

/** Trimmed and normalized forms of a submitted term. */
export function normalizeSubmittedTerm(term) {
  const submittedTerm = String(term ?? '').trim();
  return { submittedTerm, normalizedTerm: normalizeTerm(submittedTerm) };
}

/**
 * A `user_submitted_words` record. Ready submissions carry the resolved word,
 * failed ones the failure reason, queued ones neither.
 */
export function buildSubmittedWord({
  deviceId,
  userId = null,
  submittedTerm,
  normalizedTerm,
  language,
  status,
  failureReason = null,
  resolutionType = null,
  resolvedWordId = null,
  now
}) {
  return {
    id: createId('submitted_word'),
    user_id: userId,
    device_id: deviceId,
    submitted_term: submittedTerm,
    normalized_term: normalizedTerm,
    language,
    status,
    failure_reason: failureReason,
    resolution_type: resolutionType,
    resolved_word_id: resolvedWordId,
    created_at: now,
    updated_at: now,
    resolved_at: status === 'ready' ? now : null
  };
}
