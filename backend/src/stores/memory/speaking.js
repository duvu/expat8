// In-memory speaking events, weekly speaking summaries and speaking prompts.

import { createId } from '../../ids.js';
import { clampLimit } from '../../domain/pagination.js';
import {
  applySpeakingPromptPatch,
  buildSpeakingSummary,
  isPromptMissingRequiredFields,
  normalizeSpeakingEvent,
  normalizeSpeakingPromptInput,
  normalizeWeekStart
} from '../../domain/speaking.js';
import { resolveEventKey } from '../../domain/study_events.js';

export class MemorySpeakingMethods {
  recordSpeakingEvent({ deviceId, event, language = 'en', userId = null }) {
    const eventKey = resolveEventKey(event);
    if (!eventKey) {
      throw new Error('missing_event_id');
    }
    const normalized = normalizeSpeakingEvent({ deviceId, event, language, userId, strict: this.strictAttemptId });
    const existing = this.speakingEventsByKey.get(eventKey);
    if (existing) {
      return { eventId: existing.id, idempotent: true };
    }
    const stored = {
      id: createId('speaking_event'),
      ...normalized,
      event_id: event.event_id ?? eventKey,
      client_event_id: event.client_event_id ?? eventKey,
      received_at: new Date().toISOString()
    };
    this.speakingEventsByKey.set(eventKey, stored);
    return { eventId: stored.id, idempotent: false };
  }

  getSpeakingSummary({ deviceId, language = 'en', userId = null, weekStart = null }) {
    const start = normalizeWeekStart(weekStart);
    const allEvents = [...this.speakingEventsByKey.values()]
      .filter((event) => event.language === language)
      .filter((event) => (userId ? event.user_id === userId : event.device_id === deviceId && !event.user_id));
    const weekEvents = allEvents.filter((event) => event.occurred_at >= start);
    const firstRecordingEvent =
      allEvents
        .filter((e) => e.event_type === 'speaking_recorded')
        .sort((a, b) => String(a.occurred_at).localeCompare(String(b.occurred_at)))[0] ?? null;
    return buildSpeakingSummary({
      deviceId,
      userId,
      language,
      weekStart: start,
      events: weekEvents,
      firstRecordingAt: firstRecordingEvent?.occurred_at ?? null
    });
  }

  getSpeakingLoopHealthSummary({ weekStart = null } = {}) {
    const start = normalizeWeekStart(weekStart);
    const allEvents = [...this.speakingEventsByKey.values()];
    const weekEvents = allEvents.filter((e) => e.occurred_at >= start);
    const loopCompletionCount = weekEvents.filter((e) => e.event_type === 'loop_completed').length;
    const drillSessionCount = weekEvents.filter((e) => e.event_type === 'speaking_drill_completed').length;

    const latestPrompt = [...this.speakingPromptsById.values()].filter((p) => p.status === 'approved')
      .sort((a, b) => String(b.updated_at).localeCompare(String(a.updated_at)))[0] ?? null;
    const latestPassage = this.listPublishedPassages()[0] ?? null;

    return {
      week_start: start.slice(0, 10),
      loop_completion_count: loopCompletionCount,
      drill_session_count: drillSessionCount,
      latest_approved_prompt_at: latestPrompt?.updated_at ?? null,
      latest_published_passage_at: latestPassage?.created_at ?? null,
    };
  }

  listSpeakingPrompts({ status = null, missingRequired = false, limit = 100 } = {}) {
    return [...this.speakingPromptsById.values()]
      .filter((prompt) => (status ? prompt.status === status : true))
      .filter((prompt) => (missingRequired ? isPromptMissingRequiredFields(prompt) : true))
      .sort((left, right) => right.updated_at.localeCompare(left.updated_at))
      .slice(0, clampLimit(limit, 200));
  }

  createSpeakingPrompt(input) {
    const now = new Date().toISOString();
    const prompt = normalizeSpeakingPromptInput({
      ...input,
      id: input.id ?? createId('speaking_prompt'),
      status: input.status ?? 'pending_review',
      created_at: now,
      updated_at: now
    });
    this.speakingPromptsById.set(prompt.id, prompt);
    return prompt;
  }

  updateSpeakingPrompt({ promptId, patch, reviewerUserId = null }) {
    const existing = this.speakingPromptsById.get(promptId);
    if (!existing) {
      return null;
    }
    const updated = applySpeakingPromptPatch(existing, patch, { reviewerUserId, now: new Date().toISOString() });
    this.speakingPromptsById.set(updated.id, updated);
    return updated;
  }
}
