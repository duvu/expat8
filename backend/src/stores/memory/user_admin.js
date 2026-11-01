// In-memory account administration; mirrors stores/postgres/user_admin.js.

import { emptyDeletionSummary } from '../../domain/user_admin.js';
import { createPasswordHashSync } from '../../user_identity.js';

/** Deletes the entries of `map` whose value matches and returns how many went. */
function deleteWhere(map, predicate) {
  let count = 0;
  for (const [key, value] of [...map]) {
    if (predicate(value, key)) {
      map.delete(key);
      count += 1;
    }
  }
  return count;
}

export class MemoryUserAdminMethods {
  findUserById({ userId }) {
    const user = this.usersById.get(userId);
    return user ? { id: user.id, identifier: user.identifier, display_name: user.display_name } : null;
  }

  resetUserPassword({ userId, password }) {
    const user = this.usersById.get(userId);
    if (!user) {
      return null;
    }
    const now = new Date().toISOString();
    user.password_hash = createPasswordHashSync(password);
    user.updated_at = now;
    let revokedSessions = 0;
    for (const session of this.userSessionsByTokenHash.values()) {
      if (session.user_id === userId && !session.revoked_at) {
        session.revoked_at = now;
        revokedSessions += 1;
      }
    }
    return { user: { id: user.id, identifier: user.identifier }, revokedSessions };
  }

  deleteUser({ userId }) {
    const user = this.usersById.get(userId);
    if (!user) {
      return null;
    }
    const summary = emptyDeletionSummary();
    const devices = new Set(
      [...this.userSessionsByTokenHash.values()]
        .filter((session) => session.user_id === userId && session.device_id)
        .map((session) => session.device_id)
    );
    const ownedOrAnonymous = (row) =>
      row.user_id === userId || (!row.user_id && devices.has(row.device_id));

    // Content the learner owns.
    const articleIds = new Set(
      [...this.articlesById.values()].filter((a) => a.owner_user_id === userId).map((a) => a.id)
    );
    const passageIds = new Set(
      [...this.memorizationPassagesById.values()].filter((p) => p.owner_user_id === userId).map((p) => p.id)
    );
    const senseIds = new Set();
    const termIds = new Set();
    for (const term of this.articleTermsById.values()) {
      if (articleIds.has(term.article_id)) {
        termIds.add(term.id);
        if (term.word_sense_id) senseIds.add(term.word_sense_id);
      }
    }
    for (const link of this.memorizationSegmentTermsById.values()) {
      if (passageIds.has(link.passage_id) && link.word_sense_id) senseIds.add(link.word_sense_id);
    }
    const sentenceIds = new Set(
      [...this.articleWorkplaceSentenceLinksById.values()]
        .filter((link) => articleIds.has(link.article_id))
        .map((link) => link.workplace_sentence_id)
    );

    for (const prompt of this.speakingPromptsById.values()) {
      if (termIds.has(prompt.article_term_id)) prompt.article_term_id = null;
    }
    deleteWhere(this.articleTermsById, (term) => articleIds.has(term.article_id));
    deleteWhere(this.articleWorkplaceSentenceLinksById, (link) => articleIds.has(link.article_id));
    const stillLinked = new Set(
      [...this.articleWorkplaceSentenceLinksById.values()].map((link) => link.workplace_sentence_id)
    );
    deleteWhere(this.workplaceSentencesById, (sentence) => sentenceIds.has(sentence.id) && !stillLinked.has(sentence.id));
    deleteWhere(this.articleProcessingJobsById, (job) => articleIds.has(job.article_id));
    summary.articles = deleteWhere(this.articlesById, (article) => articleIds.has(article.id));

    deleteWhere(this.memorizationSegmentTermsById, (link) => passageIds.has(link.passage_id));
    const segmentIds = new Set(
      [...this.memorizationSegmentsById.values()].filter((s) => passageIds.has(s.passage_id)).map((s) => s.id)
    );
    deleteWhere(this.memorizationSegmentsById, (segment) => passageIds.has(segment.passage_id));
    summary.memorization_progress = deleteWhere(
      this.memorizationSegmentProgressById,
      (progress) => progress.user_id === userId
    );
    deleteWhere(this.memorizationSegmentProgressById, (progress) => segmentIds.has(progress.segment_id));
    summary.memorization_content = deleteWhere(this.memorizationPassagesById, (p) => passageIds.has(p.id));

    const referencedSenses = new Set();
    for (const row of [
      ...this.articleTermsById.values(),
      ...this.memorizationSegmentTermsById.values(),
      ...this.speakingPromptsById.values(),
      ...this.speakingEventsByKey.values()
    ]) {
      if (row.word_sense_id) referencedSenses.add(row.word_sense_id);
    }
    for (const pack of this.contentPacksById.values()) {
      for (const item of pack.items ?? []) {
        if (item.word_sense_id) referencedSenses.add(item.word_sense_id);
      }
    }
    deleteWhere(this.wordSensesById, (sense) => senseIds.has(sense.id) && !referencedSenses.has(sense.id));

    summary.shadowing_entries = deleteWhere(
      this.shadowingVideoEntriesById,
      (entry) => entry.owner_user_id === userId || (!entry.owner_user_id && devices.has(entry.owner_device_id))
    );

    // Exam history.
    const examSessionIds = new Set(
      [...this.examSessionsById.values()].filter((s) => s.user_id === userId).map((s) => s.id)
    );
    const attemptIds = new Set(
      [...this.examAttemptsById.values()]
        .filter((a) => a.user_id === userId || examSessionIds.has(a.session_id))
        .map((a) => a.id)
    );
    summary.exam_rows += deleteWhere(
      this.examCertificatesById,
      (cert) => cert.user_id === userId || attemptIds.has(cert.attempt_id)
    );
    summary.exam_rows += deleteWhere(this.examAttemptsById, (attempt) => attemptIds.has(attempt.id));
    deleteWhere(this.examAttemptsBySessionId, (attempt) => attemptIds.has(attempt.id));
    for (const sessionId of examSessionIds) {
      summary.exam_rows += this.examQuestionsBySessionId.get(sessionId)?.length ?? 0;
      this.examQuestionsBySessionId.delete(sessionId);
    }
    summary.exam_rows += deleteWhere(this.examSessionsById, (session) => examSessionIds.has(session.id));

    // Submitted words and learning history.
    const submissionIds = new Set(
      [...this.userSubmittedWordsById.values()].filter(ownedOrAnonymous).map((s) => s.id)
    );
    deleteWhere(this.userSubmittedWordJobsById, (job) => submissionIds.has(job.submission_id));
    summary.submitted_words = deleteWhere(this.userSubmittedWordsById, (s) => submissionIds.has(s.id));
    summary.speaking_events = deleteWhere(this.speakingEventsByKey, ownedOrAnonymous);
    summary.study_events = deleteWhere(this.studyEventsByClientId, ownedOrAnonymous);
    summary.game_rounds = deleteWhere(this.gameRoundsByClientId, ownedOrAnonymous);
    summary.word_states = deleteWhere(this.wordStatesByOwnerWord, ownedOrAnonymous);
    summary.proficiency = deleteWhere(this.userProficiencies, ownedOrAnonymous);
    summary.cached_words = deleteWhere(
      this.cachedWordIdsByOwner,
      (_cache, key) => key === `user:${userId}` || [...devices].some((device) => key === `device:${device}`)
    );

    // Keep shared admin content; only drop the reference to this reviewer.
    for (const prompt of this.speakingPromptsById.values()) {
      if (prompt.reviewer_user_id === userId) {
        prompt.reviewer_user_id = null;
        summary.cleared_reviewer_refs += 1;
      }
    }

    summary.sessions = deleteWhere(this.userSessionsByTokenHash, (session) => session.user_id === userId);
    this.usersById.delete(userId);
    this.usersByIdentifier.delete(user.identifier);
    summary.user = 1;
    return summary;
  }
}
