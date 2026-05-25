import express from 'express';
import { asyncHandler, hasAdminAccess, resolveRequiredUserSession } from './helpers.js';

const SUPPORTED_LANGUAGES = new Set(['en', 'zh', 'vi']);

export function createMemorizationRouter({ store }) {
  const router = express.Router();

  // ─── User endpoints ─────────────────────────────────────────────────

  router.post(
    '/passages',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) return;

      const body = request.body ?? {};
      const error = validatePassageInput(body);
      if (error) {
        return response.status(400).json({ error });
      }

      const passage = await store.createPassage({
        title: body.title.trim(),
        language: body.language.trim(),
        rawText: body.raw_text,
        ownerType: 'user',
        ownerUserId: userSession.user.id,
        visibility: 'private'
      });
      request.log?.info('memorization_passage_created', {
        passage_id: passage.id,
        user_id: userSession.user.id,
        language: passage.language,
        raw_text_length: body.raw_text.length
      });
      return response.status(201).json(passage);
    })
  );

  router.get(
    '/passages',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) return;

      const passages = await store.listPassages({ userId: userSession.user.id });
      return response.json({ items: passages });
    })
  );

  router.get(
    '/passages/:id',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) return;

      const passage = await store.getPassage({ passageId: request.params.id });
      if (!passage) {
        return response.status(404).json({ error: 'not_found' });
      }
      // Access check: user can see own passages or published passages
      if (passage.owner_user_id !== userSession.user.id && passage.visibility !== 'published') {
        return response.status(404).json({ error: 'not_found' });
      }

      const segments = await store.getSegmentsByPassage({ passageId: passage.id });
      return response.json({ ...passage, segments });
    })
  );

  router.delete(
    '/passages/:id',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) return;

      const passage = await store.getPassage({ passageId: request.params.id });
      if (!passage) {
        return response.status(404).json({ error: 'not_found' });
      }
      if (passage.owner_user_id !== userSession.user.id) {
        return response.status(403).json({ error: 'forbidden' });
      }

      await store.deletePassage({ passageId: passage.id });
      request.log?.info('memorization_passage_deleted', {
        passage_id: passage.id,
        user_id: userSession.user.id
      });
      return response.json({ success: true });
    })
  );

  // ─── Progress endpoints ─────────────────────────────────────────────

  router.post(
    '/progress',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) return;

      const body = request.body ?? {};
      const entries = body.entries;
      if (!Array.isArray(entries) || entries.length === 0) {
        return response.status(400).json({ error: 'entries array is required' });
      }

      const results = [];
      for (const entry of entries) {
        if (!entry.segment_id || !entry.status) continue;
        const result = await store.upsertSegmentProgress({
          userId: userSession.user.id,
          segmentId: entry.segment_id,
          status: entry.status,
          reviewCount: entry.review_count,
          easeFactor: entry.ease_factor,
          lastReviewedAt: entry.last_reviewed_at,
          nextReviewAt: entry.next_review_at
        });
        results.push(result);
      }
      request.log?.info('memorization_progress_updated', {
        user_id: userSession.user.id,
        entry_count: results.length
      });
      return response.json({ items: results });
    })
  );

  router.get(
    '/progress',
    asyncHandler(async (request, response) => {
      const userSession = await resolveRequiredUserSession({ request, response, store });
      if (!userSession) return;

      const passageId = request.query.passage_id;
      if (!passageId) {
        return response.status(400).json({ error: 'passage_id query parameter is required' });
      }

      const progress = await store.getSegmentProgress({
        userId: userSession.user.id,
        passageId
      });
      return response.json({ items: progress });
    })
  );

  return router;
}

export function createMemorizationAdminRouter({ store, config }) {
  const router = express.Router();

  router.use((request, response, next) => {
    if (!hasAdminAccess({ request, config })) {
      return response.status(403).json({ error: 'forbidden' });
    }
    return next();
  });

  // ─── Admin endpoints ────────────────────────────────────────────────

  router.post(
    '/passages',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      const error = validatePassageInput(body);
      if (error) {
        return response.status(400).json({ error });
      }

      const passage = await store.createPassage({
        title: body.title.trim(),
        language: body.language.trim(),
        rawText: body.raw_text,
        ownerType: 'admin',
        ownerUserId: null,
        visibility: body.visibility ?? 'private'
      });
      request.log?.info('memorization_admin_passage_created', {
        passage_id: passage.id,
        language: passage.language,
        visibility: passage.visibility,
        raw_text_length: body.raw_text.length
      });
      return response.status(201).json(passage);
    })
  );

  router.get(
    '/passages',
    asyncHandler(async (request, response) => {
      const status = typeof request.query.status === 'string' ? request.query.status : null;
      const passages = await store.listAdminPassages({ status });
      return response.json({ items: passages });
    })
  );

  router.get(
    '/passages/:id',
    asyncHandler(async (request, response) => {
      const passage = await store.getPassage({ passageId: request.params.id });
      if (!passage) {
        return response.status(404).json({ error: 'not_found' });
      }
      const segments = await store.getSegmentsByPassage({ passageId: passage.id });
      return response.json({ ...passage, segments });
    })
  );

  router.patch(
    '/passages/:id',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      const updates = {};
      if (typeof body.title === 'string') updates.title = body.title.trim();
      if (typeof body.language === 'string') updates.language = body.language.trim();
      if (typeof body.visibility === 'string') updates.visibility = body.visibility;

      // Handle publish action: set visibility=published + status=published if segmented
      if (body.visibility === 'published') {
        const existing = await store.getPassage({ passageId: request.params.id });
        if (existing && existing.status === 'segmented') {
          updates.status = 'published';
        }
      }

      const passage = await store.updatePassage({ passageId: request.params.id, ...updates });
      if (!passage) {
        return response.status(404).json({ error: 'not_found' });
      }
      if (updates.status === 'published') {
        request.log?.info('memorization_passage_published', {
          passage_id: passage.id,
          language: passage.language
        });
      }
      return response.json(passage);
    })
  );

  router.post(
    '/passages/:id/resegment',
    asyncHandler(async (request, response) => {
      const passage = await store.getPassage({ passageId: request.params.id });
      if (!passage) {
        return response.status(404).json({ error: 'not_found' });
      }

      await store.deleteSegmentsByPassage({ passageId: passage.id });
      const updated = await store.updatePassage({
        passageId: passage.id,
        status: 'pending_segmentation',
        processing_error: null
      });
      request.log?.info('memorization_passage_resegment_queued', {
        passage_id: passage.id,
        language: passage.language
      });
      return response.json(updated);
    })
  );

  router.patch(
    '/segments/:id',
    asyncHandler(async (request, response) => {
      const body = request.body ?? {};
      const segment = await store.updateSegment({
        segmentId: request.params.id,
        text: body.text,
        position: body.position
      });
      if (!segment) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json(segment);
    })
  );

  router.post(
    '/segments/:id/split',
    asyncHandler(async (request, response) => {
      const splitAt = Number.parseInt(String(request.body?.split_at ?? ''), 10);
      if (Number.isNaN(splitAt)) {
        return response.status(400).json({ error: 'bad_request' });
      }
      const segments = await store.splitSegment({ segmentId: request.params.id, splitAt });
      if (!segments) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json({ items: segments });
    })
  );

  router.post(
    '/segments/:id/merge',
    asyncHandler(async (request, response) => {
      const nextSegmentId = request.body?.next_segment_id;
      if (typeof nextSegmentId !== 'string' || nextSegmentId.trim().length === 0) {
        return response.status(400).json({ error: 'bad_request' });
      }
      const segments = await store.mergeSegments({
        segmentId: request.params.id,
        nextSegmentId: nextSegmentId.trim()
      });
      if (!segments) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.json({ items: segments });
    })
  );

  router.patch(
    '/passages/:id/enrich',
    asyncHandler(async (request, response) => {
      const passage = await store.getPassage({ passageId: request.params.id });
      if (!passage) {
        return response.status(404).json({ error: 'not_found' });
      }

      if (passage.status !== 'segmented' && passage.status !== 'published') {
        return response.status(400).json({ error: 'passage_not_segmented' });
      }

      await store.updatePassageEnrichmentStatus({ passageId: passage.id, enrichmentStatus: 'pending' });

      request.log?.info('memorization_passage_enrich_queued', {
        passage_id: passage.id,
        language: passage.language
      });

      return response.json({ success: true, message: 'enrichment_queued' });
    })
  );

  router.post(
    '/passages/:id/retry',
    asyncHandler(async (request, response) => {
      const result = await store.retryPassage({ passageId: request.params.id });
      if (result.error === 'not_found') {
        return response.status(404).json({ error: 'not_found' });
      }
      if (result.error === 'passage_not_failed') {
        return response.status(400).json({ error: 'passage_not_failed' });
      }

      request.log?.info('memorization_passage_retry_queued', {
        passage_id: request.params.id
      });

      return response.json({ success: true, message: 'retry_queued' });
    })
  );

  router.patch(
    '/passages/:id/retry-enrichment',
    asyncHandler(async (request, response) => {
      const result = await store.retryPassageEnrichment({ passageId: request.params.id });
      if (result.error === 'not_found') {
        return response.status(404).json({ error: 'not_found' });
      }
      if (result.error === 'enrichment_not_failed') {
        return response.status(400).json({ error: 'enrichment_not_failed' });
      }
      if (result.error === 'passage_has_no_segments') {
        return response.status(400).json({ error: 'passage_has_no_segments' });
      }

      request.log?.info('memorization_passage_enrichment_retry_queued', {
        passage_id: request.params.id
      });

      return response.json({ success: true, message: 'enrichment_retry_queued' });
    })
  );

  return router;
}

function validatePassageInput(body) {
  if (!body.title || typeof body.title !== 'string' || body.title.trim().length === 0) {
    return 'title is required';
  }
  if (!body.raw_text || typeof body.raw_text !== 'string') {
    return 'raw_text is required';
  }
  if (body.raw_text.length < 50) {
    return 'raw_text must be at least 50 characters';
  }
  if (body.raw_text.length > 20000) {
    return 'raw_text must not exceed 20000 characters';
  }
  if (!body.language || !SUPPORTED_LANGUAGES.has(body.language)) {
    return 'unsupported language';
  }
  return null;
}
