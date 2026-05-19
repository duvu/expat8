import express from 'express';
import { asyncHandler, resolveOptionalUserSession } from './helpers.js';

export function createProficiencyRouter({ store, config }) {
  const router = express.Router();

  router.get(
    '/',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const deviceId = request.query.device_id;
      if (!deviceId || typeof deviceId !== 'string') {
        return response.status(400).json({ error: 'bad_request' });
      }
      const proficiency = await store.getProficiency({
        deviceId,
        userId: userSession?.user.id ?? null,
        language: request.query.language ?? config.defaultTargetLanguage
      });
      return response.json({ device_id: deviceId, ...proficiency });
    })
  );

  return router;
}
