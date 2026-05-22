import express from 'express';
import { rateLimitMiddleware } from '../rate_limit.js';
import { InvalidStudyRatingError } from '../proficiency.js';
import { asyncHandler, resolveOptionalUserSession } from './helpers.js';

export function createStudyEventsRouter({ store, config, rateLimiters = {} }) {
  const { studyEventSyncLimiter } = rateLimiters;
  const router = express.Router();

  router.post(
    '/',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      if (!body.device_id || !(body.client_event_id || body.event_id) || !body.rating || !body.occurred_at) {
        return response.status(400).json({ error: 'bad_request' });
      }

      try {
        const result = await store.recordStudyEvent({
          deviceId: body.device_id,
          userId: userSession?.user.id ?? null,
          language: body.language ?? config.defaultTargetLanguage,
          event: {
            event_id: body.event_id ?? null,
            client_event_id: body.client_event_id ?? null,
            server_word_id: body.server_word_id ?? body.word_id ?? null,
            local_word_id: body.local_word_id ?? null,
            rating: body.rating,
            occurred_at: body.occurred_at,
            user_id: body.user_id ?? null
          }
        });
        return response.json({
          success: true,
          event_id: result.eventId,
          idempotent: result.idempotent,
          proficiency: result.proficiency
        });
      } catch (error) {
        if (error instanceof InvalidStudyRatingError) {
          request.log?.warn('study_event_rejected', {
            reason: 'invalid_rating',
            event_id: body.event_id ?? null,
            client_event_id: body.client_event_id ?? null
          });
          return response.status(400).json({ error: 'invalid_rating' });
        }
        throw error;
      }
    })
  );

  router.post(
    '/sync',
    ...(studyEventSyncLimiter ? [rateLimitMiddleware(studyEventSyncLimiter, { keyPrefix: 'sync' })] : []),
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      if (!body.device_id) {
        request.log?.warn('study_events_sync_rejected', { reason: 'missing_device_id' });
        return response.status(400).json({
          accepted_event_ids: [],
          rejected_events: [{ reason: 'missing_device_id' }]
        });
      }
      try {
        const result = await store.syncStudyEvents({
          deviceId: body.device_id,
          userId: userSession?.user.id ?? null,
          language: body.language ?? config.defaultTargetLanguage,
          events: Array.isArray(body.events) ? body.events : []
        });
        return response.json(result);
      } catch (error) {
        if (error instanceof InvalidStudyRatingError) {
          request.log?.warn('study_events_sync_rejected', { reason: 'invalid_rating' });
          return response.status(400).json({ error: 'invalid_rating' });
        }
        throw error;
      }
    })
  );

  return router;
}
