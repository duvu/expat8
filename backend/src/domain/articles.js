// Article and processing-job rules shared by both stores.

import { createId } from '../ids.js';

// Jobs left in 'processing' by a worker that died (deploy/restart) are reclaimed after this timeout.
const STALE_ARTICLE_JOB_MS = 15 * 60_000;

/** Fields an admin may patch on an article. */
export const ADMIN_ARTICLE_PATCH_FIELDS = ['title', 'language', 'visibility', 'status'];

/** A new article queued for processing; user articles have an owner, admin articles a creator. */
export function buildArticle({ ownerUserId, adminUserId, title, sourceUrl, language, rawText, visibility }) {
  const now = new Date().toISOString();
  return {
    id: createId('article'),
    owner_user_id: ownerUserId,
    created_by_admin_id: adminUserId,
    title,
    source_url: sourceUrl,
    language,
    raw_text: rawText,
    cleaned_text: null,
    visibility,
    status: 'pending_processing',
    processing_error: null,
    created_at: now,
    updated_at: now
  };
}

/** Owners see their own non-deleted articles; everyone sees published ones. */
export function isArticleReadableBy(article, userId) {
  if (article.status === 'deleted') {
    return false;
  }
  return article.owner_user_id === userId || (article.visibility === 'published' && article.status === 'published');
}

export function staleArticleJobCutoff(nowMs = Date.now()) {
  return new Date(nowMs - STALE_ARTICLE_JOB_MS).toISOString();
}
