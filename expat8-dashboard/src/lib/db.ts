import pg from 'pg';

import { getAdminConfig } from './config';
import type {
  AdminArticle,
  ExamResult,
  MemorizationPassage,
  MemorizationPassageSummary,
  MemorizationSegment,
  RecentStudyEvent,
  SpeakingPrompt,
  StudyEventSummary,
  UserDetail,
  UserProficiency,
  UserRow,
  VocabularyReviewItem,
} from '../types';

let pool: pg.Pool | null = null;

/** The dashboard's single connection pool (shared by db.ts and analytics.ts). */
export function getPool(): pg.Pool {
  if (!pool) {
    const { databaseUrl } = getAdminConfig();
    if (!databaseUrl) {
      throw new Error('EXPAT8_DASHBOARD_DATABASE_URL, WEB_ADMIN_DATABASE_URL, or DATABASE_URL is required');
    }
    pool = new pg.Pool({ connectionString: databaseUrl });
  }
  return pool;
}

async function queryRows<T extends pg.QueryResultRow>(sql: string, params: unknown[] = []): Promise<T[]> {
  return (await getPool().query<T>(sql, params)).rows;
}

export function clampLimit(limit: number, max: number) {
  return Math.max(1, Math.min(Math.trunc(limit) || 1, max));
}

// ── Articles & vocabulary review ─────────────────────────────────────────────

const ARTICLE_COLUMNS =
  'id, title, source_url, language, visibility, status, processing_error, created_at, updated_at';

export function listAdminArticles({ status = null, limit = 50 }: { status?: string | null; limit?: number } = {}) {
  return queryRows<AdminArticle>(
    `SELECT ${ARTICLE_COLUMNS}
     FROM articles
     WHERE ($1::text IS NULL OR status = $1)
     ORDER BY created_at DESC
     LIMIT $2`,
    [status, clampLimit(limit, 100)]
  );
}

export async function getAdminArticle(articleId: string): Promise<AdminArticle | null> {
  const rows = await queryRows<AdminArticle>(`SELECT ${ARTICLE_COLUMNS} FROM articles WHERE id = $1`, [articleId]);
  return rows[0] ?? null;
}

const VOCABULARY_SELECT = `
  SELECT
    vri.id,
    vri.status,
    vri.review_note,
    vri.reviewed_at,
    vri.created_at,
    a.id AS article_id,
    a.title AS article_title,
    t.display_term,
    ws.meaning_vi,
    art.surface_text AS example,
    art.sentence_context AS example_vi,
    ws.part_of_speech,
    ws.ipa
  FROM vocabulary_review_items vri
  JOIN word_senses ws ON ws.id = vri.word_sense_id
  JOIN terms t ON t.id = ws.term_id
  LEFT JOIN articles a ON a.id = vri.article_id
  LEFT JOIN article_terms art ON art.article_id = a.id AND art.word_sense_id = ws.id`;

export function listArticleVocabulary(articleId: string) {
  return queryRows<VocabularyReviewItem>(
    `${VOCABULARY_SELECT}
     WHERE vri.article_id = $1
     ORDER BY vri.created_at DESC`,
    [articleId]
  );
}

export function listPendingVocabulary(limit = 100) {
  return queryRows<VocabularyReviewItem>(
    `${VOCABULARY_SELECT}
     WHERE vri.status = 'pending'
     ORDER BY vri.created_at DESC
     LIMIT $1`,
    [clampLimit(limit, 200)]
  );
}

// ── Speaking prompts ─────────────────────────────────────────────────────────

export function listSpeakingPrompts({
  status = null,
  missingRequired = false,
  limit = 100
}: {
  status?: string | null;
  missingRequired?: boolean;
  limit?: number;
} = {}) {
  const missingClause = missingRequired
    ? `AND (sp.target_text IS NULL OR sp.target_text = '' OR sp.vi_hint IS NULL OR sp.vi_hint = '')`
    : '';
  return queryRows<SpeakingPrompt>(
    `SELECT sp.*, t.display_term, ws.meaning_vi
     FROM speaking_prompts sp
     LEFT JOIN word_senses ws ON ws.id = sp.word_sense_id
     LEFT JOIN terms t ON t.id = ws.term_id
     WHERE ($1::text IS NULL OR sp.status = $1)
     ${missingClause}
     ORDER BY sp.updated_at DESC
     LIMIT $2`,
    [status, clampLimit(limit, 200)]
  );
}

// ── Exams ────────────────────────────────────────────────────────────────────

export function listExamResults({
  userId = null,
  topic = null,
  language = null,
  limit = 100
}: {
  userId?: string | null;
  topic?: string | null;
  language?: string | null;
  limit?: number;
} = {}) {
  return queryRows<ExamResult>(
    `SELECT
       ea.id, ea.user_id, ea.topic, ea.language, ea.difficulty_level, ea.total_questions,
       ea.correct_count, ea.score_pct, ea.passed, ea.created_at,
       ec.id AS certificate_id
     FROM exam_attempts ea
     LEFT JOIN exam_certificates ec ON ec.attempt_id = ea.id
     WHERE ($1::text IS NULL OR ea.user_id = $1)
       AND ($2::text IS NULL OR ea.topic = $2)
       AND ($3::text IS NULL OR ea.language = $3)
     ORDER BY ea.created_at DESC
     LIMIT $4`,
    [userId, topic, language, clampLimit(limit, 500)]
  );
}

// ── Users ────────────────────────────────────────────────────────────────────

export const USERS_PAGE_SIZE = 50;

export async function listUsers({ page = 1 }: { page?: number } = {}): Promise<UserRow[]> {
  const rows = await queryRows<Omit<UserRow, 'study_event_count'> & { study_event_count: string }>(
    `SELECT
       u.id,
       u.identifier,
       u.display_name,
       u.created_at,
       MAX(se.occurred_at) AS last_activity,
       COUNT(se.id)::text AS study_event_count
     FROM users u
     LEFT JOIN study_events se ON se.user_id = u.id
     GROUP BY u.id, u.identifier, u.display_name, u.created_at
     ORDER BY u.created_at DESC
     LIMIT $1 OFFSET $2`,
    [USERS_PAGE_SIZE, (Math.max(1, page) - 1) * USERS_PAGE_SIZE]
  );
  return rows.map((row) => ({ ...row, study_event_count: Number(row.study_event_count) }));
}

export async function getUserDetail(userId: string): Promise<UserDetail | null> {
  const rows = await queryRows<Omit<UserDetail, 'session_count' | 'cached_word_count'> & {
    session_count: string;
    cached_word_count: string;
  }>(
    `SELECT
       u.id,
       u.identifier,
       u.display_name,
       u.created_at,
       (SELECT COUNT(*)::text FROM user_sessions us WHERE us.user_id = u.id) AS session_count,
       (SELECT COUNT(*)::text FROM user_cached_words ucw WHERE ucw.user_id = u.id) AS cached_word_count
     FROM users u
     WHERE u.id = $1`,
    [userId]
  );
  const row = rows[0];
  if (!row) return null;
  return {
    ...row,
    session_count: Number(row.session_count),
    cached_word_count: Number(row.cached_word_count),
  };
}

export function getUserProficiency(userId: string) {
  return queryRows<UserProficiency>(
    `SELECT language, level, updated_at
     FROM user_proficiency
     WHERE user_id = $1
     ORDER BY language`,
    [userId]
  );
}

export async function getUserStudyStats(
  userId: string
): Promise<{ breakdown: StudyEventSummary[]; recentEvents: RecentStudyEvent[] }> {
  const [breakdown, recentEvents] = await Promise.all([
    queryRows<{ rating: string; count: string }>(
      `SELECT rating, COUNT(*)::text AS count
       FROM study_events
       WHERE user_id = $1
       GROUP BY rating
       ORDER BY rating`,
      [userId]
    ),
    queryRows<RecentStudyEvent>(
      `SELECT id, word_id, local_word_id, rating, occurred_at
       FROM study_events
       WHERE user_id = $1
       ORDER BY occurred_at DESC
       LIMIT 20`,
      [userId]
    ),
  ]);
  return {
    breakdown: breakdown.map((row) => ({ rating: row.rating, count: Number(row.count) })),
    recentEvents,
  };
}

// ── Memorization passages ────────────────────────────────────────────────────

export function listMemorizationPassages({ status = null, limit = 50 }: { status?: string | null; limit?: number } = {}) {
  return queryRows<MemorizationPassageSummary>(
    `SELECT id, title, language, owner_type, owner_user_id, visibility, status, enrichment_status,
            segment_count, processing_error, attempt_count, enrichment_attempt_count, created_at, updated_at
     FROM memorization_passages
     WHERE ($1::text IS NULL OR status = $1)
     ORDER BY created_at DESC
     LIMIT $2`,
    [status, clampLimit(limit, 200)]
  );
}

export async function getMemorizationPassage(id: string): Promise<MemorizationPassage | null> {
  const [passages, segments] = await Promise.all([
    queryRows<Omit<MemorizationPassage, 'segments'>>(`SELECT * FROM memorization_passages WHERE id = $1`, [id]),
    queryRows<MemorizationSegment>(
      `SELECT id, passage_id, position, text, word_count, ipa_text, translation_text, translation_language, created_at
       FROM memorization_segments
       WHERE passage_id = $1
       ORDER BY position ASC`,
      [id]
    ),
  ]);
  return passages[0] ? { ...passages[0], segments } : null;
}
