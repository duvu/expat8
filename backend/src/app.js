import { readJson, sendJson } from './http_utils.js';
import { toApiWord } from './word_store.js';

export function createApp({ store, generationService, config }) {
  return async function app(request, response) {
    const url = new URL(request.url, `http://${request.headers.host ?? 'localhost'}`);

    try {
      if (request.method === 'GET' && url.pathname === '/health') {
        return sendJson(response, 200, { ok: true });
      }

      if (request.method === 'GET' && url.pathname === '/v1/words/next') {
        const limit = clampLimit(url.searchParams.get('limit'), 1, 20);
        const targetLanguage =
          url.searchParams.get('target_language') ?? config.defaultTargetLanguage;
        let words = store.findNewWords({ targetLanguage, limit });
        if (words.length < limit && generationService) {
          const generated = await generationService.generateAndStore({
            sourceLanguage:
              url.searchParams.get('source_language') ?? config.defaultSourceLanguage,
            targetLanguage,
            limit: limit - words.length
          });
          words = [...words, ...generated].slice(0, limit);
        }
        return sendJson(response, 200, { items: words.map(toApiWord) });
      }

      if (request.method === 'GET' && url.pathname === '/v1/words/recent') {
        const limit = clampLimit(url.searchParams.get('limit'), 1, 1000);
        const targetLanguage =
          url.searchParams.get('target_language') ?? config.defaultTargetLanguage;
        const words = store.recentWords({ targetLanguage, limit });
        return sendJson(response, 200, { items: words.map(toApiWord) });
      }

      if (request.method === 'POST' && url.pathname === '/v1/study-events/sync') {
        const body = await readJson(request);
        if (!body.device_id) {
          return sendJson(response, 400, {
            accepted_event_ids: [],
            rejected_events: [{ reason: 'missing_device_id' }]
          });
        }
        const result = store.syncStudyEvents({
          deviceId: body.device_id,
          events: Array.isArray(body.events) ? body.events : []
        });
        return sendJson(response, 200, result);
      }

      return sendJson(response, 404, { error: 'not_found' });
    } catch (error) {
      return sendJson(response, 500, { error: 'internal_error', message: error.message });
    }
  };
}

function clampLimit(raw, min, max) {
  const parsed = Number.parseInt(raw ?? `${min}`, 10);
  if (Number.isNaN(parsed)) {
    return min;
  }
  return Math.max(min, Math.min(max, parsed));
}
