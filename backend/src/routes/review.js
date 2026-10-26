import express from 'express';
import { decodeReviewCursor, toReviewStatesPage } from '../domain/review_states.js';
import { asyncHandler, queryLimit, resolveOptionalUserSession } from './helpers.js';

/**
 * GET /v1/review/states — the learner's SRS states changed since `cursor`, so an offline-first
 * device can catch up (new phone, reinstall, another family member's device) after syncing events.
 */
export function createReviewRouter({ store, config }) {
  const router = express.Router();

  router.get(
    '/states',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const deviceId = request.query.device_id;
      if (!deviceId || typeof deviceId !== 'string') {
        return response.status(400).json({ error: 'bad_request' });
      }
      const limit = queryLimit(request.query.limit, 200, 500);
      const rows = await store.listWordStatesSince({
        deviceId,
        userId: userSession?.user.id ?? null,
        language: request.query.language ?? config.defaultTargetLanguage,
        cursor: decodeReviewCursor(request.query.cursor),
        limit
      });
      const requestCursor = typeof request.query.cursor === 'string' ? request.query.cursor : null;
      return response.json(toReviewStatesPage({ rows, limit, requestCursor }));
    })
  );

  return router;
}
