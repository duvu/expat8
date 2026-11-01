import type pg from 'pg';

import { getPool } from './db';

// Analytics are read-only dashboard widgets: a failing query logs and renders an
// empty/zero widget instead of failing the whole page.
async function safe<T>(label: string, fallback: T, run: (pool: pg.Pool) => Promise<T>): Promise<T> {
  try {
    return await run(getPool());
  } catch (error) {
    console.error(`[analytics] ${label} failed:`, error);
    return fallback;
  }
}

function toNum(value: unknown): number {
  return value == null ? 0 : Number(value);
}

function round1(value: number) {
  return Math.round(value * 10) / 10;
}

function pct(part: number, total: number) {
  return total > 0 ? round1((part / total) * 100) : 0;
}

/** ISO timestamp `days` ago. Timestamps are stored as ISO-8601 TEXT, so string comparison is chronological. */
function sinceIso(days: number) {
  return new Date(Date.now() - days * 86_400_000).toISOString();
}

/** UTC calendar day (YYYY-MM-DD) `days` ago. */
function sinceDay(days: number) {
  return sinceIso(days).slice(0, 10);
}

/** Article processing job statuses written by the backend article worker. */
const JOB_PENDING = `('pending_processing')`;
const JOB_SUCCEEDED = `('processed', 'pending_review')`;
const JOB_FAILED = `('processing_failed', 'dead_lettered')`;

const ACTIVE_LEARNER = 'COALESCE(user_id, device_id)';

// ── Home dashboard ───────────────────────────────────────────────────────────

export function getAnalyticsKpis() {
  const fallback = {
    totalUsers: 0,
    activeUsers7d: 0,
    studyEventsToday: 0,
    totalStudyEvents: 0,
    examPassRate: 0,
    speakingDrillsThisWeek: 0,
  };
  return safe('kpis', fallback, async (pool) => {
    const sevenDaysAgo = sinceDay(7);
    const { rows } = await pool.query<Record<keyof typeof fallback, string>>(
      `SELECT
         (SELECT COUNT(*) FROM users)::text AS "totalUsers",
         (SELECT COUNT(DISTINCT ${ACTIVE_LEARNER}) FROM study_events WHERE occurred_at >= $1)::text AS "activeUsers7d",
         (SELECT COUNT(*) FROM study_events WHERE occurred_at >= $2)::text AS "studyEventsToday",
         (SELECT COUNT(*) FROM study_events)::text AS "totalStudyEvents",
         (SELECT COALESCE(AVG(passed) * 100, 0) FROM exam_attempts)::text AS "examPassRate",
         (SELECT COUNT(*) FROM speaking_events
          WHERE event_type = 'speaking_drill_completed' AND occurred_at >= $1)::text AS "speakingDrillsThisWeek"`,
      [sevenDaysAgo, sinceDay(0)],
    );
    const row = rows[0];
    return {
      totalUsers: toNum(row?.totalUsers),
      activeUsers7d: toNum(row?.activeUsers7d),
      studyEventsToday: toNum(row?.studyEventsToday),
      totalStudyEvents: toNum(row?.totalStudyEvents),
      examPassRate: round1(toNum(row?.examPassRate)),
      speakingDrillsThisWeek: toNum(row?.speakingDrillsThisWeek),
    };
  });
}

// ── Study events ─────────────────────────────────────────────────────────────

export function getStudyEventTimeSeries(days: number) {
  return safe('study event time series', [] as Array<{ date: string; events: number; learners: number }>, async (pool) => {
    const { rows } = await pool.query<{ date: string; events: string; learners: string }>(
      `SELECT
         SUBSTRING(occurred_at, 1, 10) AS date,
         COUNT(*)::text AS events,
         COUNT(DISTINCT ${ACTIVE_LEARNER})::text AS learners
       FROM study_events
       WHERE occurred_at >= $1
       GROUP BY 1
       ORDER BY 1`,
      [sinceDay(days)],
    );
    return rows.map((r) => ({ date: r.date, events: toNum(r.events), learners: toNum(r.learners) }));
  });
}

type RatingRow = { date: string; easy: number; too_easy: number; hard: number; too_hard: number };

export function getStudyEventsByRating(days: number) {
  return safe('study events by rating', [] as RatingRow[], async (pool) => {
    const { rows } = await pool.query<Record<keyof RatingRow, string>>(
      `SELECT
         SUBSTRING(occurred_at, 1, 10) AS date,
         COUNT(*) FILTER (WHERE rating = 'easy')::text     AS easy,
         COUNT(*) FILTER (WHERE rating = 'too_easy')::text AS too_easy,
         COUNT(*) FILTER (WHERE rating = 'hard')::text     AS hard,
         COUNT(*) FILTER (WHERE rating = 'too_hard')::text AS too_hard
       FROM study_events
       WHERE occurred_at >= $1
       GROUP BY 1
       ORDER BY 1`,
      [sinceDay(days)],
    );
    return rows.map((r) => ({
      date: r.date,
      easy: toNum(r.easy),
      too_easy: toNum(r.too_easy),
      hard: toNum(r.hard),
      too_hard: toNum(r.too_hard),
    }));
  });
}

export function getActiveUserMetrics() {
  return safe('active user metrics', { dau: 0, wau: 0, mau: 0 }, async (pool) => {
    const { rows } = await pool.query<{ dau: string; wau: string; mau: string }>(
      `SELECT
         COUNT(DISTINCT ${ACTIVE_LEARNER}) FILTER (WHERE occurred_at >= $1)::text AS dau,
         COUNT(DISTINCT ${ACTIVE_LEARNER}) FILTER (WHERE occurred_at >= $2)::text AS wau,
         COUNT(DISTINCT ${ACTIVE_LEARNER})::text AS mau
       FROM study_events
       WHERE occurred_at >= $3`,
      [sinceDay(0), sinceDay(7), sinceDay(30)],
    );
    return { dau: toNum(rows[0]?.dau), wau: toNum(rows[0]?.wau), mau: toNum(rows[0]?.mau) };
  });
}

// ── Content pipeline ─────────────────────────────────────────────────────────

/** Article processing queue health; p50 covers successful jobs from the last 30 days. */
export function getPipelineHealth() {
  const fallback = { queueDepth: 0, failedLast24h: 0, p50Seconds: null as number | null };
  return safe('pipeline health', fallback, async (pool) => {
    const { rows } = await pool.query<{ pending: string; failed24h: string; p50: string | null }>(
      `SELECT
         COUNT(*) FILTER (WHERE status IN ${JOB_PENDING})::text AS pending,
         COUNT(*) FILTER (WHERE status IN ${JOB_FAILED} AND updated_at >= $1)::text AS failed24h,
         (PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (finished_at::timestamptz - started_at::timestamptz))
          ) FILTER (
            WHERE status IN ${JOB_SUCCEEDED}
              AND started_at IS NOT NULL AND finished_at IS NOT NULL
              AND created_at >= $2
          ))::text AS p50
       FROM article_processing_jobs`,
      [sinceIso(1), sinceIso(30)],
    );
    const row = rows[0];
    return {
      queueDepth: toNum(row?.pending),
      failedLast24h: toNum(row?.failed24h),
      p50Seconds: row?.p50 != null ? Number(row.p50) : null,
    };
  });
}

export function getArticleStatusCounts() {
  return safe('article status counts', [] as Array<{ status: string; count: number }>, async (pool) => {
    const { rows } = await pool.query<{ status: string; count: string }>(
      `SELECT status, COUNT(*)::text AS count FROM articles GROUP BY status ORDER BY COUNT(*) DESC`,
    );
    return rows.map((r) => ({ status: r.status, count: toNum(r.count) }));
  });
}

type GenerationRun = {
  id: string;
  status: string;
  requested_count: number;
  inserted_count: number;
  duration_s: number | null;
  error: string | null;
};

export function getGenerationRuns(limit = 50) {
  return safe('generation runs', [] as GenerationRun[], async (pool) => {
    const { rows } = await pool.query<{
      id: string;
      status: string;
      requested_count: number | null;
      inserted_count: number | null;
      started_at: string | null;
      finished_at: string | null;
      error_message: string | null;
    }>(
      `SELECT id, status, requested_count, inserted_count, started_at, finished_at, error_message
       FROM generation_runs
       ORDER BY started_at DESC
       LIMIT $1`,
      [Math.max(1, Math.min(limit, 200))],
    );
    return rows.map((r) => ({
      id: r.id,
      status: r.status,
      requested_count: r.requested_count ?? 0,
      inserted_count: r.inserted_count ?? 0,
      duration_s: secondsBetween(r.started_at, r.finished_at),
      error: r.error_message,
    }));
  });
}

type ArticleProcessingJob = {
  id: string;
  status: string;
  attempt_count: number;
  started_at: string | null;
  duration_s: number | null;
  error_message: string | null;
};

export function getArticleProcessingJobs(articleId: string) {
  return safe('article processing jobs', [] as ArticleProcessingJob[], async (pool) => {
    const { rows } = await pool.query<Omit<ArticleProcessingJob, 'duration_s'> & { finished_at: string | null }>(
      `SELECT id, status, attempt_count, started_at, finished_at, error_message
       FROM article_processing_jobs
       WHERE article_id = $1
       ORDER BY created_at DESC`,
      [articleId],
    );
    return rows.map(({ finished_at, ...job }) => ({ ...job, duration_s: secondsBetween(job.started_at, finished_at) }));
  });
}

function secondsBetween(start: string | null, end: string | null): number | null {
  if (!start || !end) return null;
  return round1((new Date(end).getTime() - new Date(start).getTime()) / 1000);
}

// ── Speaking ─────────────────────────────────────────────────────────────────

export function getSpeakingEventTimeSeries(days: number) {
  return safe('speaking time series', [] as Array<{ date: string; events: number }>, async (pool) => {
    const { rows } = await pool.query<{ date: string; events: string }>(
      `SELECT SUBSTRING(occurred_at, 1, 10) AS date, COUNT(*)::text AS events
       FROM speaking_events
       WHERE occurred_at >= $1
       GROUP BY 1
       ORDER BY 1`,
      [sinceDay(days)],
    );
    return rows.map((r) => ({ date: r.date, events: toNum(r.events) }));
  });
}

export function getSpeakingSelfRatingDistribution(days: number) {
  const fallback = { clear: 0, hesitated: 0, could_not_say: 0 };
  return safe('speaking self ratings', fallback, async (pool) => {
    const { rows } = await pool.query<{ self_rating: string; count: string }>(
      `SELECT self_rating, COUNT(*)::text AS count
       FROM speaking_events
       WHERE self_rating IS NOT NULL AND occurred_at >= $1
       GROUP BY self_rating`,
      [sinceDay(days)],
    );
    const counts = Object.fromEntries(rows.map((r) => [r.self_rating, toNum(r.count)]));
    return {
      clear: counts.clear ?? 0,
      hesitated: counts.hesitated ?? 0,
      could_not_say: counts.could_not_say ?? 0,
    };
  });
}

export function getSpeakingDrillStats(days: number) {
  const fallback = { completed: 0, completionRatePct: 0, avgDurationSeconds: 0 };
  return safe('speaking drill stats', fallback, async (pool) => {
    const { rows } = await pool.query<{ started: string; completed: string; avg_ms: string | null }>(
      `SELECT
         COUNT(DISTINCT attempt_id)::text AS started,
         COUNT(*) FILTER (WHERE event_type = 'speaking_drill_completed')::text AS completed,
         (AVG(total_duration_ms) FILTER (WHERE event_type = 'speaking_drill_completed'))::text AS avg_ms
       FROM speaking_events
       WHERE occurred_at >= $1`,
      [sinceDay(days)],
    );
    const started = toNum(rows[0]?.started);
    const completed = toNum(rows[0]?.completed);
    return {
      completed,
      completionRatePct: pct(completed, started),
      avgDurationSeconds: round1(toNum(rows[0]?.avg_ms) / 1000),
    };
  });
}

export function getSpeakingPromptCoverage() {
  return safe('speaking prompt coverage', { coveragePct: 0 }, async (pool) => {
    const { rows } = await pool.query<{ approved: string; total: string }>(
      `SELECT
         (SELECT COUNT(*) FROM speaking_prompts WHERE status = 'approved')::text AS approved,
         (SELECT COUNT(*) FROM word_senses)::text AS total`,
    );
    return { coveragePct: pct(toNum(rows[0]?.approved), toNum(rows[0]?.total)) };
  });
}

// ── Exams ────────────────────────────────────────────────────────────────────

export function getExamAnalytics(days: number) {
  const fallback = { totalAttempts: 0, passRatePct: 0, avgScorePct: 0 };
  return safe('exam analytics', fallback, async (pool) => {
    const { rows } = await pool.query<{ total: string; pass_rate: string; avg_score: string }>(
      `SELECT
         COUNT(*)::text AS total,
         COALESCE(AVG(passed) * 100, 0)::text AS pass_rate,
         COALESCE(AVG(score_pct), 0)::text AS avg_score
       FROM exam_attempts
       WHERE created_at >= $1`,
      [sinceDay(days)],
    );
    return {
      totalAttempts: toNum(rows[0]?.total),
      passRatePct: round1(toNum(rows[0]?.pass_rate)),
      avgScorePct: round1(toNum(rows[0]?.avg_score)),
    };
  });
}

export function getExamScoreDistribution(days: number) {
  return safe('exam score distribution', [] as Array<{ bucket: string; count: number }>, async (pool) => {
    // 10-point buckets; 100 joins the 90-100 bucket.
    const { rows } = await pool.query<{ lo: number; count: string }>(
      `SELECT LEAST(FLOOR(score_pct / 10), 9)::int * 10 AS lo, COUNT(*)::text AS count
       FROM exam_attempts
       WHERE created_at >= $1
       GROUP BY 1
       ORDER BY 1`,
      [sinceDay(days)],
    );
    return rows.map((r) => ({ bucket: r.lo === 90 ? '90-100' : `${r.lo}-${r.lo + 9}`, count: toNum(r.count) }));
  });
}

type ExamTopicRow = { topic: string; language: string; attempts: number; passRate: number; avgScore: number };

export function getExamTopicBreakdown(days: number) {
  return safe('exam topic breakdown', [] as ExamTopicRow[], async (pool) => {
    const { rows } = await pool.query<{ topic: string; language: string; attempts: string; pass_rate: string; avg_score: string }>(
      `SELECT
         topic,
         language,
         COUNT(*)::text AS attempts,
         (AVG(passed) * 100)::text AS pass_rate,
         AVG(score_pct)::text AS avg_score
       FROM exam_attempts
       WHERE created_at >= $1
       GROUP BY topic, language
       ORDER BY COUNT(*) DESC`,
      [sinceDay(days)],
    );
    return rows.map((r) => ({
      topic: r.topic,
      language: r.language,
      attempts: toNum(r.attempts),
      passRate: round1(toNum(r.pass_rate)),
      avgScore: round1(toNum(r.avg_score)),
    }));
  });
}

// ── SRS ──────────────────────────────────────────────────────────────────────

export function getSrsOverview() {
  const fallback = { byStatus: {} as Record<string, number>, overdue: 0 };
  return safe('srs overview', fallback, async (pool) => {
    const [statusResult, overdueResult] = await Promise.all([
      pool.query<{ status: string; count: string }>(
        `SELECT status, COUNT(*)::text AS count FROM user_word_states GROUP BY status`,
      ),
      pool.query<{ count: string }>(
        `SELECT COUNT(*)::text AS count FROM user_word_states WHERE next_review_at IS NOT NULL AND next_review_at < $1`,
        [new Date().toISOString()],
      ),
    ]);
    return {
      byStatus: Object.fromEntries(statusResult.rows.map((r) => [r.status, toNum(r.count)])),
      overdue: toNum(overdueResult.rows[0]?.count),
    };
  });
}

// ── Content coverage ─────────────────────────────────────────────────────────

export function getWordTopicCoverage() {
  const fallback = { rows: [] as Array<{ topic: string; count: number }>, totalWords: 0 };
  return safe('word topic coverage', fallback, async (pool) => {
    // topics_json is stored as a JSON text array, e.g. '["finance","tech"]'
    const [topics, total] = await Promise.all([
      pool.query<{ topic: string; count: string }>(
        `SELECT topic, COUNT(*)::text AS count
         FROM words, LATERAL jsonb_array_elements_text(topics_json::jsonb) AS topic
         GROUP BY topic
         ORDER BY COUNT(*) DESC`,
      ),
      pool.query<{ total: string }>(`SELECT COUNT(*)::text AS total FROM words`),
    ]);
    return {
      rows: topics.rows.map((r) => ({ topic: r.topic, count: toNum(r.count) })),
      totalWords: toNum(total.rows[0]?.total),
    };
  });
}

export function getEntryTypeDistribution() {
  return safe('entry type distribution', [] as Array<{ type: string; count: number }>, async (pool) => {
    const { rows } = await pool.query<{ type: string; count: string }>(
      `SELECT entry_type AS type, COUNT(*)::text AS count FROM words GROUP BY entry_type ORDER BY COUNT(*) DESC`,
    );
    return rows.map((r) => ({ type: r.type, count: toNum(r.count) }));
  });
}

export function getQualityScoreHistogram() {
  const fallback = { rows: [] as Array<{ bucket: string; count: number }>, avgScore: null as number | null };
  return safe('quality score histogram', fallback, async (pool) => {
    const [hist, avg] = await Promise.all([
      pool.query<{ lo: number | null; count: string }>(
        `SELECT
           CASE WHEN quality_score IS NULL THEN NULL ELSE LEAST(FLOOR(quality_score * 10), 9)::int END AS lo,
           COUNT(*)::text AS count
         FROM word_senses
         GROUP BY 1
         ORDER BY 1 NULLS FIRST`,
      ),
      pool.query<{ avg: string | null }>(
        `SELECT AVG(quality_score)::text AS avg FROM word_senses WHERE quality_score IS NOT NULL`,
      ),
    ]);
    return {
      rows: hist.rows.map((r) => ({
        bucket: r.lo == null ? 'unscored' : `${(r.lo / 10).toFixed(1)}-${((r.lo + 1) / 10).toFixed(1)}`,
        count: toNum(r.count),
      })),
      avgScore: avg.rows[0]?.avg != null ? Number(avg.rows[0].avg) : null,
    };
  });
}

/** New study words per day: content goes live as soon as it is created, so this is the pipeline's output. */
export function getWordsAddedPerDay(days: number) {
  return safe('words added per day', [] as Array<{ date: string; words: number }>, async (pool) => {
    const { rows } = await pool.query<{ date: string; words: string }>(
      `SELECT SUBSTRING(created_at, 1, 10) AS date, COUNT(*)::text AS words
       FROM words
       WHERE created_at >= $1
       GROUP BY 1
       ORDER BY 1`,
      [sinceDay(days)],
    );
    return rows.map((r) => ({ date: r.date, words: toNum(r.words) }));
  });
}

// ── Workplace sentences ──────────────────────────────────────────────────────

type WorkplaceSentence = {
  id: string;
  text: string;
  topic: string | null;
  language: string;
  article_id: string | null;
  created_at: string;
};

export function listWorkplaceSentences({
  topic = null,
  language = null,
  limit = 50,
}: { topic?: string | null; language?: string | null; limit?: number } = {}) {
  return safe('workplace sentences', [] as WorkplaceSentence[], async (pool) => {
    const { rows } = await pool.query<WorkplaceSentence>(
      `SELECT ws.id, ws.text, ws.topic, ws.language, MAX(aws.article_id) AS article_id, ws.created_at
       FROM workplace_sentences ws
       LEFT JOIN article_workplace_sentences aws ON aws.workplace_sentence_id = ws.id
       WHERE ($1::text IS NULL OR ws.topic = $1)
         AND ($2::text IS NULL OR ws.language = $2)
       GROUP BY ws.id
       ORDER BY ws.created_at DESC
       LIMIT $3`,
      [topic, language, Math.max(1, Math.min(limit, 200))],
    );
    return rows;
  });
}

export function getArticleWorkplaceSentences(articleId: string) {
  return safe('article workplace sentences', [] as Omit<WorkplaceSentence, 'article_id'>[], async (pool) => {
    const { rows } = await pool.query<Omit<WorkplaceSentence, 'article_id'>>(
      `SELECT ws.id, ws.text, ws.topic, ws.language, ws.created_at
       FROM workplace_sentences ws
       JOIN article_workplace_sentences aws ON aws.workplace_sentence_id = ws.id
       WHERE aws.article_id = $1
       ORDER BY ws.created_at ASC`,
      [articleId],
    );
    return rows;
  });
}

// ── Per-user drill-down ──────────────────────────────────────────────────────

type UserSrsState = {
  word_id: string;
  term: string | null;
  status: string;
  ease_factor: number | null;
  review_count: number;
  next_review_at: string | null;
};

export function getUserSrsStates(userId: string) {
  return safe('user srs states', [] as UserSrsState[], async (pool) => {
    const { rows } = await pool.query<UserSrsState>(
      `SELECT uws.word_id, w.term, uws.status, uws.ease_factor, uws.review_count, uws.next_review_at
       FROM user_word_states uws
       LEFT JOIN words w ON w.id = uws.word_id
       WHERE uws.user_id = $1
       ORDER BY uws.next_review_at ASC NULLS LAST`,
      [userId],
    );
    return rows;
  });
}

export function getUserSpeakingStats(userId: string) {
  const fallback = {
    totalEvents: 0,
    drillsCompleted: 0,
    lastSpeakingAt: null as string | null,
    selfRatingDistribution: [] as Array<{ rating: string; count: number }>,
  };
  return safe('user speaking stats', fallback, async (pool) => {
    const [summary, ratings] = await Promise.all([
      pool.query<{ total: string; drills: string; last_at: string | null }>(
        `SELECT
           COUNT(*)::text AS total,
           COUNT(*) FILTER (WHERE event_type = 'speaking_drill_completed')::text AS drills,
           MAX(occurred_at) AS last_at
         FROM speaking_events
         WHERE user_id = $1`,
        [userId],
      ),
      pool.query<{ rating: string; count: string }>(
        `SELECT self_rating AS rating, COUNT(*)::text AS count
         FROM speaking_events
         WHERE user_id = $1 AND self_rating IS NOT NULL
         GROUP BY self_rating
         ORDER BY COUNT(*) DESC`,
        [userId],
      ),
    ]);
    const row = summary.rows[0];
    return {
      totalEvents: toNum(row?.total),
      drillsCompleted: toNum(row?.drills),
      lastSpeakingAt: row?.last_at ?? null,
      selfRatingDistribution: ratings.rows.map((r) => ({ rating: r.rating, count: toNum(r.count) })),
    };
  });
}
