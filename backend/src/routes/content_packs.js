import express from 'express';
import { asyncHandler, clampLimit, resolveOptionalUserSession } from './helpers.js';

export function createContentPacksRouter({ store, config }) {
  const router = express.Router();

  router.get(
    '/',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const language = request.query.language ?? request.query.target_language ?? config.defaultTargetLanguage;
      const afterVersion =
        request.query.after_version == null ? null : Number.parseInt(request.query.after_version, 10);
      const limit = clampLimit(request.query.limit, 1, 200);
      const items = await store.listContentPacks({
        language,
        afterVersion: Number.isNaN(afterVersion) ? null : afterVersion,
        limit
      });
      return response.json({ items });
    })
  );

  router.get(
    '/:id',
    asyncHandler(async (request, response) => {
      const userSession = await resolveOptionalUserSession({ request, response, store });
      if (userSession === false) {
        return;
      }
      const pack = await store.getContentPackById({ id: request.params.id });
      if (!pack) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(pack);
    })
  );

  return router;
}
