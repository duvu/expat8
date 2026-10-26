import express from 'express';
import { rateLimitMiddleware } from '../rate_limit.js';
import { normalizeDifficultyLevel } from '../proficiency.js';
import { toApiWord } from '../domain/vocabulary.js';
import { asyncHandler, queryLimit, resolveOptionalUserSession } from './helpers.js';

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
      const limit = queryLimit(body.limit, 10, 100);
      const targetLanguage = body.target_language ?? config.defaultTargetLanguage;
      // Optional study-level override (the learner picked a level for this session). Absent/null means
      // "use the learner's own proficiency level".
      const requestedLevel = body.level ?? null;
      const level =
        requestedLevel === null ? null : normalizeDifficultyLevel(requestedLevel, { language: targetLanguage });
      if (requestedLevel !== null && level === null) {
        return response.status(400).json({ error: 'bad_request' });
      }
      const result = await store.learningCards({
        deviceId: body.device_id,
        userId: userSession?.user.id ?? null,
        targetLanguage,
        limit,
        level,
        now: new Date().toISOString()
      });
      return response.json({
        level: result.level,
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
