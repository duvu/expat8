import express from 'express';
import { GAME_MODES } from '../game_rounds.js';
import { asyncHandler, clampLimit, resolveOptionalUserSession, resolveRequiredUserSession } from './helpers.js';

const MAX_ROUNDS_PER_REQUEST = 50;

export function createGamesRouter({ store }) {
  const router = express.Router();

  // Finished rounds synced from the offline queue (idempotent by client_round_id).
  router.post(
    '/rounds',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const body = request.body ?? {};
      const deviceId = body.device_id;
      if (!deviceId || typeof deviceId !== 'string' || !Array.isArray(body.rounds)) {
        return response.status(400).json({ error: 'bad_request' });
      }
      if (body.rounds.length === 0 || body.rounds.length > MAX_ROUNDS_PER_REQUEST) {
        return response.status(400).json({ error: 'bad_request' });
      }
      const result = await store.recordGameRounds({
        deviceId,
        userId: userSession?.user.id ?? null,
        rounds: body.rounds
      });
      return response.json(result);
    })
  );

  // Weekly best score per signed-in learner.
  router.get(
    '/leaderboard',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) {
        return;
      }
      const game = typeof request.query.game === 'string' ? request.query.game : 'word_blaster';
      const mode = typeof request.query.mode === 'string' ? request.query.mode : 'classic';
      if (!GAME_MODES[game]?.includes(mode)) {
        return response.status(400).json({ error: 'bad_request' });
      }
      const leaderboard = await store.getGameLeaderboard({
        game,
        mode,
        weekStart: typeof request.query.week_start === 'string' ? request.query.week_start : null,
        userId: userSession.user.id,
        limit: clampLimit(request.query.limit ?? 50, 1, 100)
      });
      return response.json(leaderboard);
    })
  );

  return router;
}
