import express from 'express';
import { rateLimitMiddleware } from '../rate_limit.js';
import { toApiWord } from '../word_store.js';
import { asyncHandler, clampLimit, resolveOptionalUserSession } from './helpers.js';

export function createLearningRouter({ store, config, rateLimiters = {} }) {
  const { learningCardsLimiter } = rateLimiters;
  const router = express.Router();

  router.post(
    '/cards',
    ...(learningCardsLimiter ? [rateLimitMiddleware(learningCardsLimiter, { keyPrefix: 'cards' })] : []),
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      if (!body.device_id || typeof body.device_id !== 'string' || hasClientWordExclusions(body)) {
        return response.status(400).json({ error: 'bad_request' });
      }
      if (normalizeCardMode(body.card_mode) !== 'new') {
        return response.status(400).json({ error: 'bad_request' });
      }
      const limit = clampLimit(body.limit ?? 10, 1, 100);
      const targetLanguage = body.target_language ?? config.defaultTargetLanguage;
      const result = await store.learningCards({
        deviceId: body.device_id,
        userId: userSession?.user.id ?? null,
        targetLanguage,
        limit,
        now: new Date().toISOString()
      });
      return response.json({
        target_mix: result.target_mix,
        actual_mix: result.actual_mix,
        items: result.items.map((card) => ({
          ...toApiWord(card.word),
          card_type: card.cardType,
          selection_reason: card.selectionReason
        }))
      });
    })
  );

  return router;
}

function hasClientWordExclusions(body) {
  return Object.keys(body).some((key) =>
    [
      'exclude_server_word_id',
      'exclude_server_word_ids',
      'excludeServerWordId',
      'excludeServerWordIds',
      'current_word_id',
      'current_server_word_id'
    ].includes(key)
  );
}

function normalizeCardMode(value) {
  return value === 'new' || value === undefined || value === null || value === '' ? 'new' : String(value);
}
