// In-memory memorization passages, segments and per-learner segment progress.

import { createId } from '../../ids.js';
import {
  countWords,
  mergeSegmentText,
  splitSegmentText,
  summarizePassageProgress
} from '../../domain/memorization.js';

export class MemoryMemorizationMethods {
  createPassage({ title, language, rawText, ownerType = 'user', ownerUserId = null, visibility = 'private' }) {
    const now = new Date().toISOString();
    const passage = {
      id: createId('passage'),
      title,
      language,
      raw_text: rawText,
      owner_type: ownerType,
      owner_user_id: ownerUserId,
      visibility,
      status: 'pending_segmentation',
      enrichment_status: 'none',
      processing_error: null,
      segment_count: 0,
      attempt_count: 0,
      enrichment_attempt_count: 0,
      created_at: now,
      updated_at: now
    };
    this.memorizationPassagesById.set(passage.id, passage);
    return passage;
  }

  getPassage({ passageId }) {
    return this.memorizationPassagesById.get(passageId) ?? null;
  }

  listPassages({ userId = null, status = null, ownerType = null } = {}) {
    let passages = [...this.memorizationPassagesById.values()];
    if (status) {
      passages = passages.filter((p) => p.status === status);
    }
    if (ownerType) {
      passages = passages.filter((p) => p.owner_type === ownerType);
    }
    if (userId) {
      // User sees: own passages + published passages
      passages = passages.filter(
        (p) => p.owner_user_id === userId || p.visibility === 'published'
      );
    }
    return passages.sort((a, b) => b.created_at.localeCompare(a.created_at));
  }

  listPublishedPassages() {
    return [...this.memorizationPassagesById.values()]
      .filter((p) => p.visibility === 'published' && p.status === 'published')
      .sort((a, b) => b.created_at.localeCompare(a.created_at));
  }

  listAdminPassages({ status = null } = {}) {
    let passages = [...this.memorizationPassagesById.values()];
    if (status) {
      passages = passages.filter((p) => p.status === status);
    }
    return passages.sort((a, b) => b.created_at.localeCompare(a.created_at));
  }

  updatePassage({ passageId, ...updates }) {
    const passage = this.memorizationPassagesById.get(passageId);
    if (!passage) return null;
    const allowed = ['title', 'language', 'visibility', 'status', 'enrichment_status', 'processing_error', 'segment_count', 'attempt_count', 'enrichment_attempt_count'];
    for (const key of allowed) {
      if (updates[key] !== undefined) {
        passage[key] = updates[key];
      }
    }
    passage.updated_at = new Date().toISOString();
    return passage;
  }

  deletePassage({ passageId }) {
    const passage = this.memorizationPassagesById.get(passageId);
    if (!passage) return false;
    deleteSegmentsWithProgress(this, passageId);
    this.memorizationPassagesById.delete(passageId);
    return true;
  }

  // ─── Memorization Segments ──────────────────────────────────────────

  createSegments({ passageId, segments }) {
    const now = new Date().toISOString();
    const created = [];
    for (const seg of segments) {
      const segment = {
        id: createId('segment'),
        passage_id: passageId,
        position: seg.position,
        text: seg.text,
        word_count: seg.text.split(/\s+/).length,
        ipa_text: null,
        translation_text: null,
        translation_language: null,
        viet_reading_text: null,
        created_at: now
      };
      this.memorizationSegmentsById.set(segment.id, segment);
      created.push(segment);
    }
    // Update passage segment_count
    const passage = this.memorizationPassagesById.get(passageId);
    if (passage) {
      passage.segment_count = created.length;
      passage.updated_at = now;
    }
    return created;
  }

  getSegmentsByPassage({ passageId }) {
    return [...this.memorizationSegmentsById.values()]
      .filter((s) => s.passage_id === passageId)
      .sort((a, b) => a.position - b.position);
  }

  updateSegment({ segmentId, text, position }) {
    const segment = this.memorizationSegmentsById.get(segmentId);
    if (!segment) return null;
    if (text !== undefined) {
      segment.text = text;
      segment.word_count = text.split(/\s+/).length;
    }
    if (position !== undefined) {
      segment.position = position;
    }
    return segment;
  }

  splitSegment({ segmentId, splitAt }) {
    const segment = this.memorizationSegmentsById.get(segmentId);
    if (!segment) return null;
    const split = splitSegmentText(segment.text, splitAt);
    if (!split) {
      return null;
    }
    const { leftText, rightText } = split;

    const now = new Date().toISOString();
    const originalPosition = segment.position;
    for (const other of this.memorizationSegmentsById.values()) {
      if (other.passage_id === segment.passage_id && other.position > originalPosition) {
        other.position += 1;
      }
    }

    segment.text = leftText;
    segment.word_count = countWords(leftText);
    const newSegment = {
      id: createId('segment'),
      passage_id: segment.passage_id,
      position: originalPosition + 1,
      text: rightText,
      word_count: countWords(rightText),
      created_at: now
    };
    this.memorizationSegmentsById.set(newSegment.id, newSegment);
    refreshPassageSegmentCount(this, segment.passage_id);
    return this.getSegmentsByPassage({ passageId: segment.passage_id });
  }

  mergeSegments({ segmentId, nextSegmentId }) {
    const segment = this.memorizationSegmentsById.get(segmentId);
    const next = this.memorizationSegmentsById.get(nextSegmentId);
    if (!segment || !next || segment.passage_id !== next.passage_id) {
      return null;
    }
    if (next.position !== segment.position + 1) {
      return null;
    }

    segment.text = mergeSegmentText(segment.text, next.text);
    segment.word_count = countWords(segment.text);
    this.memorizationSegmentsById.delete(next.id);
    for (const progress of this.memorizationSegmentProgressById.values()) {
      if (progress.segment_id === next.id) {
        progress.segment_id = segment.id;
      }
    }
    for (const link of this.memorizationSegmentTermsById.values()) {
      if (link.segment_id === next.id) {
        link.segment_id = segment.id;
      }
    }
    for (const other of this.memorizationSegmentsById.values()) {
      if (other.passage_id === segment.passage_id && other.position > next.position) {
        other.position -= 1;
      }
    }
    refreshPassageSegmentCount(this, segment.passage_id);
    return this.getSegmentsByPassage({ passageId: segment.passage_id });
  }

  deleteSegmentsByPassage({ passageId }) {
    deleteSegmentsWithProgress(this, passageId);
    const passage = this.memorizationPassagesById.get(passageId);
    if (passage) {
      passage.segment_count = 0;
      passage.updated_at = new Date().toISOString();
    }
  }

  // ─── Memorization Segment Progress ──────────────────────────────────

  upsertSegmentProgress({ userId, segmentId, status, reviewCount, easeFactor, lastReviewedAt, nextReviewAt }) {
    // Find existing by user+segment
    const existing = [...this.memorizationSegmentProgressById.values()].find(
      (p) => p.user_id === userId && p.segment_id === segmentId
    );
    const now = new Date().toISOString();
    if (existing) {
      if (status !== undefined) existing.status = status;
      if (reviewCount !== undefined) existing.review_count = reviewCount;
      if (easeFactor !== undefined) existing.ease_factor = easeFactor;
      if (lastReviewedAt !== undefined) existing.last_reviewed_at = lastReviewedAt;
      if (nextReviewAt !== undefined) existing.next_review_at = nextReviewAt;
      existing.updated_at = now;
      return existing;
    }
    const progress = {
      id: createId('segprog'),
      user_id: userId,
      segment_id: segmentId,
      status: status ?? 'new',
      review_count: reviewCount ?? 0,
      ease_factor: easeFactor ?? 2.5,
      last_reviewed_at: lastReviewedAt ?? null,
      next_review_at: nextReviewAt ?? null,
      created_at: now,
      updated_at: now
    };
    this.memorizationSegmentProgressById.set(progress.id, progress);
    return progress;
  }

  getSegmentProgress({ userId, passageId }) {
    const segmentIds = new Set(
      this.getSegmentsByPassage({ passageId }).map((s) => s.id)
    );
    return [...this.memorizationSegmentProgressById.values()].filter(
      (p) => p.user_id === userId && segmentIds.has(p.segment_id)
    );
  }

  getPassageProgress({ userId, passageId }) {
    return summarizePassageProgress(
      this.getSegmentsByPassage({ passageId }),
      this.getSegmentProgress({ userId, passageId })
    );
  }

  claimNextPendingPassage() {
    for (const passage of this.memorizationPassagesById.values()) {
      if (passage.status === 'pending_segmentation') {
        passage.status = 'segmenting';
        passage.updated_at = new Date().toISOString();
        return passage;
      }
    }
    return null;
  }

  updateSegmentEnrichment({ segmentId, ipa_text, translation_text, translation_language, viet_reading_text }) {
    const segment = this.memorizationSegmentsById.get(segmentId);
    if (!segment) return null;
    segment.ipa_text = ipa_text ?? null;
    segment.translation_text = translation_text ?? null;
    segment.translation_language = translation_language ?? null;
    segment.viet_reading_text = viet_reading_text ?? null;
    return segment;
  }

  updatePassageEnrichmentStatus({ passageId, enrichmentStatus, enrichment_attempt_count }) {
    const passage = this.memorizationPassagesById.get(passageId);
    if (!passage) return null;
    passage.enrichment_status = enrichmentStatus;
    if (enrichment_attempt_count !== undefined) {
      passage.enrichment_attempt_count = enrichment_attempt_count;
    }
    passage.updated_at = new Date().toISOString();
    return passage;
  }

  claimNextPendingEnrichment() {
    for (const passage of this.memorizationPassagesById.values()) {
      if (passage.enrichment_status === 'pending') {
        passage.enrichment_status = 'enriching';
        passage.updated_at = new Date().toISOString();
        return passage;
      }
    }
    return null;
  }

  retryPassage({ passageId }) {
    const passage = this.memorizationPassagesById.get(passageId);
    if (!passage) return { error: 'not_found' };
    if (passage.status !== 'failed') return { error: 'passage_not_failed' };
    passage.status = 'pending_segmentation';
    passage.processing_error = null;
    passage.attempt_count = 0;
    passage.updated_at = new Date().toISOString();
    return { passage };
  }

  retryPassageEnrichment({ passageId }) {
    const passage = this.memorizationPassagesById.get(passageId);
    if (!passage) return { error: 'not_found' };
    if (passage.enrichment_status !== 'failed') return { error: 'enrichment_not_failed' };
    const segmentCount = [...this.memorizationSegmentsById.values()].filter(
      (s) => s.passage_id === passageId
    ).length;
    if (segmentCount === 0) return { error: 'passage_has_no_segments' };
    passage.enrichment_status = 'pending';
    passage.enrichment_attempt_count = 0;
    passage.updated_at = new Date().toISOString();
    return { passage };
  }
}

// Removes a passage's vocabulary links, segments and the learners' progress on them.
function deleteSegmentsWithProgress(store, passageId) {
  deletePassageVocabularyLinks(store, passageId);
  for (const [id, segment] of store.memorizationSegmentsById) {
    if (segment.passage_id !== passageId) {
      continue;
    }
    for (const [progressId, progress] of store.memorizationSegmentProgressById) {
      if (progress.segment_id === id) {
        store.memorizationSegmentProgressById.delete(progressId);
      }
    }
    store.memorizationSegmentsById.delete(id);
  }
}

function refreshPassageSegmentCount(store, passageId) {
  const passage = store.memorizationPassagesById.get(passageId);
  if (passage) {
    passage.segment_count = store.getSegmentsByPassage({ passageId }).length;
    passage.updated_at = new Date().toISOString();
  }
}

// Removes a passage's segment-term links and the senses/review items created for them.
export function deletePassageVocabularyLinks(store, passageId) {
  const oldSenseIds = [];
  for (const [id, link] of store.memorizationSegmentTermsById) {
    if (link.passage_id === passageId) {
      if (link.word_sense_id) oldSenseIds.push(link.word_sense_id);
      store.memorizationSegmentTermsById.delete(id);
    }
  }
  if (oldSenseIds.length === 0) {
    return;
  }
  const oldSenseIdSet = new Set(oldSenseIds);
  for (const [id, item] of store.vocabularyReviewItemsById) {
    if (oldSenseIdSet.has(item.word_sense_id)) {
      store.vocabularyReviewItemsById.delete(id);
    }
  }
  for (const id of oldSenseIdSet) {
    store.wordSensesById.delete(id);
  }
}
