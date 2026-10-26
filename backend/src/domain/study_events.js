// Study-event sync rules shared by both stores: idempotency keys, projection
// order, per-event validation and the routing of a sync batch to the
// speaking/study recorders.

import { isSpeakingEvent, isUnknownSpeakingEvent } from './speaking.js';

const EVENT_VALIDATION_MESSAGES = new Set([
  'missing_event_id',
  'missing_required_field',
  'invalid_speaking_event',
  'invalid_speaking_event_type',
  'invalid_self_rating',
  'forbidden_audio_field'
]);

export function resolveEventKey(event) {
  if (event?.event_id && typeof event.event_id === 'string') {
    return event.event_id;
  }
  if (event?.client_event_id && typeof event.client_event_id === 'string') {
    return event.client_event_id;
  }
  return null;
}

function compareEventsForProjection(left, right) {
  const occurred = String(left.occurred_at ?? '').localeCompare(String(right.occurred_at ?? ''));
  if (occurred !== 0) {
    return occurred;
  }
  const received = String(left.received_at ?? '').localeCompare(String(right.received_at ?? ''));
  if (received !== 0) {
    return received;
  }
  return resolveEventKey(left)?.localeCompare(resolveEventKey(right) ?? '') ?? -1;
}

// Only problems with the submitted event become `rejected_events`, which
// clients treat as permanent. Storage failures (connection loss, schema drift,
// constraint mismatches) propagate as 5xx so the client keeps the event queued
// and retries after the server is fixed.
export function isEventDataError(error) {
  if (error?.name === 'InvalidStudyRatingError' || EVENT_VALIDATION_MESSAGES.has(error?.message)) {
    return true;
  }
  const code = typeof error?.code === 'string' ? error.code : '';
  // 22xxx: invalid input value (e.g. malformed timestamp); 23503: unknown referenced row.
  return code.startsWith('22') || code === '23503';
}

/**
 * Routes a sync batch (in projection order) to the async speaking/study
 * recorders. Errors that are not event-data errors propagate.
 *
 * @returns {Promise<{ accepted, duplicates, rejected, latestProficiency }>}
 */
export async function routeStudyEvents({ events, recordSpeakingEvent, recordStudyEvent, initialProficiency }) {
  const outcome = createOutcome(initialProficiency);
  for (const event of [...events].sort(compareEventsForProjection)) {
    const route = classifyEvent(event);
    if (route.rejection) {
      outcome.rejected.push(route.rejection);
      continue;
    }
    try {
      const record = route.kind === 'speaking' ? recordSpeakingEvent : recordStudyEvent;
      recordOutcome(outcome, route, await record(event));
    } catch (error) {
      if (!isEventDataError(error)) {
        throw error;
      }
      outcome.rejected.push(rejection(event, errorReason(route.kind, error)));
    }
  }
  return outcome;
}

/**
 * Synchronous twin of routeStudyEvents for the in-memory store. Every recorder
 * error rejects the event (there is no storage layer that could fail).
 */
export function routeStudyEventsSync({ events, recordSpeakingEvent, recordStudyEvent, initialProficiency }) {
  const outcome = createOutcome(initialProficiency);
  for (const event of [...events].sort(compareEventsForProjection)) {
    const route = classifyEvent(event);
    if (route.rejection) {
      outcome.rejected.push(route.rejection);
      continue;
    }
    try {
      const record = route.kind === 'speaking' ? recordSpeakingEvent : recordStudyEvent;
      recordOutcome(outcome, route, record(event));
    } catch (error) {
      outcome.rejected.push(rejection(event, errorReason(route.kind, error)));
    }
  }
  return outcome;
}

/** API shape of a sync response. */
export function toSyncResponse({ accepted, duplicates, rejected, latestProficiency }) {
  return {
    accepted_event_ids: accepted,
    duplicates,
    rejected_events: rejected,
    proficiency: latestProficiency
  };
}

function createOutcome(initialProficiency) {
  return { accepted: [], duplicates: [], rejected: [], latestProficiency: initialProficiency };
}

// Decides which recorder handles the event, or rejects it up front when it is malformed.
function classifyEvent(event) {
  const eventKey = resolveEventKey(event);
  if (isSpeakingEvent(event)) {
    if (!eventKey || !event.occurred_at) {
      return { rejection: rejection(event, 'missing_required_field') };
    }
    return { kind: 'speaking', eventKey };
  }
  if (isUnknownSpeakingEvent(event)) {
    return { rejection: rejection(event, 'invalid_speaking_event_type') };
  }
  if (!eventKey || !event.rating || !event.occurred_at) {
    return { rejection: rejection(event, 'missing_required_field') };
  }
  return { kind: 'study', eventKey };
}

function recordOutcome(outcome, route, result) {
  if (route.kind === 'study') {
    outcome.latestProficiency = result.proficiency;
  }
  (result.idempotent ? outcome.duplicates : outcome.accepted).push(route.eventKey);
}

function errorReason(kind, error) {
  if (kind === 'speaking') {
    return error.message === 'forbidden_audio_field' ? 'forbidden_audio_field' : 'invalid_speaking_event';
  }
  return error.name === 'InvalidStudyRatingError' ? 'invalid_rating' : 'invalid_event';
}

function rejection(event, reason) {
  return {
    client_event_id: event.client_event_id ?? null,
    event_id: event.event_id ?? null,
    reason
  };
}
