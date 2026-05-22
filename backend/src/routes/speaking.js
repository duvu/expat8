import express from 'express';
import { toApiSpeakingPrompt } from '../word_store.js';
import { asyncHandler, clampLimit, resolveOptionalUserSession } from './helpers.js';

export function createSpeakingRouter({ store, config }) {
  const router = express.Router();

  router.get(
    '/prompts',
    asyncHandler(async (request, response) => {
      const limit = clampLimit(request.query.limit ?? 100, 1, 200);
      const wordSenseId = typeof request.query.word_sense_id === 'string' ? request.query.word_sense_id : null;
      let prompts = await store.listSpeakingPrompts({ status: 'approved', limit });
      if (wordSenseId) {
        prompts = prompts.filter((p) => p.word_sense_id === wordSenseId);
      }
      return response.json({ items: prompts.map(toApiSpeakingPrompt) });
    })
  );

  router.get(
    '/summary',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const deviceId = request.query.device_id;
      if (!deviceId || typeof deviceId !== 'string') {
        return response.status(400).json({ error: 'bad_request' });
      }
      const summary = await store.getSpeakingSummary({
        deviceId,
        userId: userSession?.user.id ?? null,
        language: request.query.language ?? config.defaultTargetLanguage,
        weekStart: typeof request.query.week_start === 'string' ? request.query.week_start : null
      });
      return response.json(summary);
    })
  );

  return router;
}
