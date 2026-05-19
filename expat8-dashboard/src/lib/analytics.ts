import pg from 'pg';

import { getAdminConfig } from './config';

// ── Pool (private, same pattern as db.ts) ────────────────────────────────────

let analyticsPool: pg.Pool | null = null;

function getPool(): pg.Pool {
  const config = getAdminConfig();
  if (!config.databaseUrl) {
    throw new Error(
      'EXPAT8_DASHBOARD_DATABASE_URL, WEB_ADMIN_DATABASE_URL, or DATABASE_URL is required',
    );
  }
  if (!analyticsPool) {
    analyticsPool = new pg.Pool({ connectionString: config.databaseUrl });
  }
  return analyticsPool;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function toNum(v: unknown): number {
  return v == null ? 0 : Number(v);
}

// ── KPI data for home dashboard ───────────────────────────────────────────────

export async function getAnalyticsKpis(): Promise<{
  totalUsers: number;
  activeUsers7d: number;
  studyEventsToday: number;
  totalStudyEvents: number;
  examPassRate: number;
  speakingDrillsThisWeek: number;
}> {
  try {
    const pool = getPool();
    const today = new Date().toISOString().slice(0, 10);
    const sevenDaysAgo = new Date(Date.now() - 7 * 86400_000).toISOString().slice(0, 10);

    const [users, events, todayEvents, exam, speaking] = await Promise.all([
      pool.query<{ total: string; active7d: string }>(
        `SELECT
           COUNT(*)::text AS total,
           (SELECT COUNT(DISTINCT COALESCE(user_id, device_id))::text
            FROM study_events
            WHERE occurred_at >= $1) AS active7d
         FROM users`,
        [sevenDaysAgo],
      ),
      pool.query<{ total: string }>(
        `SELECT COUNT(*)::text AS total FROM study_events`,
      ),
      pool.query<{ cnt: string }>(
        `SELECT COUNT(*)::text AS cnt FROM study_events WHERE occurred_at >= $1`,
        [today],
      ),
      pool.query<{ pass_rate: string }>(
        `SELECT
           CASE WHEN COUNT(*) = 0 THEN '0'
                ELSE (SUM(CASE WHEN passed = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*))::text
           END AS pass_rate
         FROM exam_attempts`,
      ),
      pool.query<{ cnt: string }>(
        `SELECT COUNT(*)::text AS cnt
         FROM speaking_events
         WHERE event_type = 'speaking_drill_completed'
           AND occurred_at >= $1`,
        [sevenDaysAgo],
      ),
    ]);

    return {
      totalUsers: toNum(users.rows[0]?.total),
      activeUsers7d: toNum(users.rows[0]?.active7d),
      studyEventsToday: toNum(todayEvents.rows[0]?.cnt),
      totalStudyEvents: toNum(events.rows[0]?.total),
      examPassRate: Math.round(toNum(exam.rows[0]?.pass_rate) * 10) / 10,
      speakingDrillsThisWeek: toNum(speaking.rows[0]?.cnt),
    };
  } catch {
    return {
      totalUsers: 0,
      activeUsers7d: 0,
      studyEventsToday: 0,
      totalStudyEvents: 0,
      examPassRate: 0,
      speakingDrillsThisWeek: 0,
    };
  }
}

// ── Daily study event time-series ─────────────────────────────────────────────

export async function getStudyEventTimeSeries(
  intervalDays: number,
): Promise<Array<{ date: string; events: number; learners: number }>> {
  try {
    const since = new Date(Date.now() - intervalDays * 86400_000)
      .toISOString()
      .slice(0, 10);
    const result = await getPool().query<{
      date: string;
      events: string;
      learners: string;
    }>(
      `SELECT
         SUBSTRING(occurred_at, 1, 10) AS date,
         COUNT(*)::text AS events,
         COUNT(DISTINCT COALESCE(user_id, device_id))::text AS learners
       FROM study_events
       WHERE occurred_at >= $1
       GROUP BY SUBSTRING(occurred_at, 1, 10)
       ORDER BY date ASC`,
      [since],
    );
    return result.rows.map(r => ({
      date: r.date,
      events: toNum(r.events),
      learners: toNum(r.learners),
    }));
  } catch {
    return [];
  }
}

// ── Study events by rating (stacked chart) ────────────────────────────────────

export async function getStudyEventsByRating(
  intervalDays: number,
): Promise<
  Array<{ date: string; easy: number; too_easy: number; hard: number; too_hard: number }>
> {
  try {
    const since = new Date(Date.now() - intervalDays * 86400_000)
      .toISOString()
      .slice(0, 10);
    const result = await getPool().query<{
      date: string;
      easy: string;
      too_easy: string;
      hard: string;
      too_hard: string;
    }>(
      `SELECT
         SUBSTRING(occurred_at, 1, 10) AS date,
         SUM(CASE WHEN rating = 'easy'     THEN 1 ELSE 0 END)::text AS easy,
         SUM(CASE WHEN rating = 'too_easy' THEN 1 ELSE 0 END)::text AS too_easy,
         SUM(CASE WHEN rating = 'hard'     THEN 1 ELSE 0 END)::text AS hard,
         SUM(CASE WHEN rating = 'too_hard' THEN 1 ELSE 0 END)::text AS too_hard
       FROM study_events
       WHERE occurred_at >= $1
       GROUP BY SUBSTRING(occurred_at, 1, 10)
       ORDER BY date ASC`,
      [since],
    );
    return result.rows.map(r => ({
      date: r.date,
      easy: toNum(r.easy),
      too_easy: toNum(r.too_easy),
      hard: toNum(r.hard),
      too_hard: toNum(r.too_hard),
    }));
  } catch {
    return [];
  }
}

// ── DAU / WAU / MAU ───────────────────────────────────────────────────────────

export async function getActiveUserMetrics(): Promise<{
  dau: number;
  wau: number;
  mau: number;
}> {
  try {
    const today = new Date().toISOString().slice(0, 10);
    const weekAgo = new Date(Date.now() - 7 * 86400_000).toISOString().slice(0, 10);
    const monthAgo = new Date(Date.now() - 30 * 86400_000).toISOString().slice(0, 10);

    const result = await getPool().query<{ dau: string; wau: string; mau: string }>(
      `SELECT
         (SELECT COUNT(DISTINCT COALESCE(user_id, device_id))::text FROM study_events WHERE occurred_at >= $1) AS dau,
         (SELECT COUNT(DISTINCT COALESCE(user_id, device_id))::text FROM study_events WHERE occurred_at >= $2) AS wau,
         (SELECT COUNT(DISTINCT COALESCE(user_id, device_id))::text FROM study_events WHERE occurred_at >= $3) AS mau`,
      [today, weekAgo, monthAgo],
    );
    const row = result.rows[0];
    return {
      dau: toNum(row?.dau),
      wau: toNum(row?.wau),
      mau: toNum(row?.mau),
    };
  } catch {
    return { dau: 0, wau: 0, mau: 0 };
  }
}

// ── Pipeline health ───────────────────────────────────────────────────────────
// Fields: queue_depth (alias for pending), failed_last_24h

export async function getPipelineHealth(): Promise<{
  queue_depth: number;
  failed_last_24h: number;
  p50DurationSeconds: number | null;
}> {
  try {
    const since24h = new Date(Date.now() - 86400_000).toISOString();

    const result = await getPool().query<{
      pending: string;
      failed24h: string;
      p50_sec: string | null;
    }>(
      `WITH durations AS (
         SELECT
           EXTRACT(EPOCH FROM (finished_at::timestamptz - started_at::timestamptz)) AS dur_sec
         FROM article_processing_jobs
         WHERE status = 'completed'
           AND finished_at IS NOT NULL AND started_at IS NOT NULL
       )
       SELECT
         (SELECT COUNT(*)::text FROM article_processing_jobs WHERE status = 'pending') AS pending,
         (SELECT COUNT(*)::text FROM article_processing_jobs
          WHERE status = 'failed' AND created_at >= $1) AS failed24h,
         (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dur_sec)::text FROM durations) AS p50_sec`,
      [since24h],
    );
    const row = result.rows[0];
    return {
      queue_depth: toNum(row?.pending),
      failed_last_24h: toNum(row?.failed24h),
      p50DurationSeconds: row?.p50_sec != null ? Number(row.p50_sec) : null,
    };
  } catch {
    return { queue_depth: 0, failed_last_24h: 0, p50DurationSeconds: null };
  }
}

// ── Article status counts ─────────────────────────────────────────────────────

export async function getArticleStatusCounts(): Promise<
  Array<{ status: string; count: number }>
> {
  try {
    const result = await getPool().query<{ status: string; count: string }>(
      `SELECT status, COUNT(*)::text AS count
       FROM articles
       GROUP BY status
       ORDER BY count DESC`,
    );
    return result.rows.map(r => ({ status: r.status, count: toNum(r.count) }));
  } catch {
    return [];
  }
}

// ── Processing job stats ──────────────────────────────────────────────────────
// p50_duration_s is used by the pipeline page

export async function getProcessingJobStats(intervalDays = 30): Promise<{
  p50_duration_s: number;
  p50: number | null;
  p95: number | null;
  failureRate: number;
  totalCompleted: number;
}> {
  try {
    const since = new Date(Date.now() - intervalDays * 86400_000).toISOString();
    const result = await getPool().query<{
      p50: string | null;
      p95: string | null;
      total: string;
      failed: string;
    }>(
      `WITH jobs AS (
         SELECT
           status,
           CASE WHEN finished_at IS NOT NULL AND started_at IS NOT NULL
                THEN EXTRACT(EPOCH FROM (finished_at::timestamptz - started_at::timestamptz))
                ELSE NULL
           END AS dur_sec
         FROM article_processing_jobs
         WHERE created_at >= $1
       )
       SELECT
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dur_sec)::text AS p50,
         PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY dur_sec)::text AS p95,
         COUNT(*)::text AS total,
         SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END)::text AS failed
       FROM jobs`,
      [since],
    );
    const row = result.rows[0];
    const total = toNum(row?.total);
    const failed = toNum(row?.failed);
    const p50Val = row?.p50 != null ? Number(row.p50) : null;
    return {
      p50_duration_s: p50Val ?? 0,
      p50: p50Val,
      p95: row?.p95 != null ? Number(row.p95) : null,
      failureRate: total > 0 ? Math.round((failed / total) * 1000) / 10 : 0,
      totalCompleted: total - failed,
    };
  } catch {
    return { p50_duration_s: 0, p50: null, p95: null, failureRate: 0, totalCompleted: 0 };
  }
}

// ── Generation runs history ───────────────────────────────────────────────────
// Fields: duration_s (computed), error (alias for error_message)

export async function getGenerationRuns(limit = 50): Promise<
  Array<{
    id: string;
    status: string;
    requested_count: number;
    inserted_count: number;
    started_at: string | null;
    finished_at: string | null;
    duration_s: number | null;
    error: string | null;
  }>
> {
  try {
    const cappedLimit = Math.max(1, Math.min(limit, 200));
    const result = await getPool().query<{
      id: string;
      status: string;
      requested_count: number | null;
      inserted_count: number | null;
      started_at: string;
      finished_at: string;
      error_message: string | null;
    }>(
      `SELECT id, status, requested_count, inserted_count, started_at, finished_at, error_message
       FROM generation_runs
       ORDER BY started_at DESC
       LIMIT $1`,
      [cappedLimit],
    );
    return result.rows.map(r => ({
      id: r.id,
      status: r.status,
      requested_count: r.requested_count ?? 0,
      inserted_count: r.inserted_count ?? 0,
      started_at: r.started_at,
      finished_at: r.finished_at,
      duration_s:
        r.started_at && r.finished_at
          ? Math.round(
              (new Date(r.finished_at).getTime() - new Date(r.started_at).getTime()) / 100,
            ) / 10
          : null,
      error: r.error_message,
    }));
  } catch {
    return [];
  }
}

// ── Speaking event time-series ────────────────────────────────────────────────
// Note: page uses key 'events' not 'total'

export async function getSpeakingEventTimeSeries(
  intervalDays: number,
): Promise<Array<{ date: string; events: number; recorded: number; drill_completed: number }>> {
  try {
    const since = new Date(Date.now() - intervalDays * 86400_000)
      .toISOString()
      .slice(0, 10);
    const result = await getPool().query<{
      date: string;
      events: string;
      recorded: string;
      drill_completed: string;
    }>(
      `SELECT
         SUBSTRING(occurred_at, 1, 10) AS date,
         COUNT(*)::text AS events,
         SUM(CASE WHEN event_type = 'speaking_recorded'        THEN 1 ELSE 0 END)::text AS recorded,
         SUM(CASE WHEN event_type = 'speaking_drill_completed'  THEN 1 ELSE 0 END)::text AS drill_completed
       FROM speaking_events
       WHERE occurred_at >= $1
       GROUP BY SUBSTRING(occurred_at, 1, 10)
       ORDER BY date ASC`,
      [since],
    );
    return result.rows.map(r => ({
      date: r.date,
      events: toNum(r.events),
      recorded: toNum(r.recorded),
      drill_completed: toNum(r.drill_completed),
    }));
  } catch {
    return [];
  }
}

// ── Speaking self-rating distribution ────────────────────────────────────────
// Returns object with keys: clear, hesitated, could_not_say

export async function getSpeakingSelfRatingDistribution(
  _intervalDays?: number,
): Promise<{ clear: number; hesitated: number; could_not_say: number }> {
  try {
    const result = await getPool().query<{ self_rating: string; count: string }>(
      `SELECT self_rating, COUNT(*)::text AS count
       FROM speaking_events
       WHERE self_rating IS NOT NULL
       GROUP BY self_rating`,
    );
    const map: Record<string, number> = {};
    for (const r of result.rows) {
      map[r.self_rating] = toNum(r.count);
    }
    return {
      clear: map['clear'] ?? 0,
      hesitated: map['hesitated'] ?? 0,
      could_not_say: map['could_not_say'] ?? 0,
    };
  } catch {
    return { clear: 0, hesitated: 0, could_not_say: 0 };
  }
}

// ── Speaking drill stats ──────────────────────────────────────────────────────
// Fields: total_completed, completion_rate_pct, avg_duration_s

export async function getSpeakingDrillStats(
  _intervalDays?: number,
): Promise<{
  total_completed: number;
  completion_rate_pct: number;
  avg_duration_s: number;
  drillsStarted: number;
  avgDurationMs: number | null;
}> {
  try {
    const result = await getPool().query<{
      started: string;
      completed: string;
      avg_dur_ms: string | null;
    }>(
      `SELECT
         COUNT(DISTINCT attempt_id)::text AS started,
         SUM(CASE WHEN event_type = 'speaking_drill_completed' THEN 1 ELSE 0 END)::text AS completed,
         AVG(CASE WHEN event_type = 'speaking_drill_completed' THEN total_duration_ms ELSE NULL END)::text AS avg_dur_ms
       FROM speaking_events`,
    );
    const row = result.rows[0];
    const started = toNum(row?.started);
    const completed = toNum(row?.completed);
    const avgDurMs = row?.avg_dur_ms != null ? Number(row.avg_dur_ms) : null;
    return {
      total_completed: completed,
      completion_rate_pct: started > 0 ? Math.round((completed / started) * 1000) / 10 : 0,
      avg_duration_s: avgDurMs != null ? Math.round(avgDurMs / 100) / 10 : 0,
      drillsStarted: started,
      avgDurationMs: avgDurMs,
    };
  } catch {
    return {
      total_completed: 0,
      completion_rate_pct: 0,
      avg_duration_s: 0,
      drillsStarted: 0,
      avgDurationMs: null,
    };
  }
}

// ── Speaking prompt coverage ──────────────────────────────────────────────────
// Field: coverage_pct

export async function getSpeakingPromptCoverage(): Promise<{
  approvedPrompts: number;
  totalWordSenses: number;
  coverage_pct: number;
}> {
  try {
    const result = await getPool().query<{
      approved: string;
      total_senses: string;
    }>(
      `SELECT
         (SELECT COUNT(*)::text FROM speaking_prompts WHERE status = 'approved') AS approved,
         (SELECT COUNT(*)::text FROM word_senses) AS total_senses`,
    );
    const row = result.rows[0];
    const approved = toNum(row?.approved);
    const total = toNum(row?.total_senses);
    return {
      approvedPrompts: approved,
      totalWordSenses: total,
      coverage_pct: total > 0 ? Math.round((approved / total) * 1000) / 10 : 0,
    };
  } catch {
    return { approvedPrompts: 0, totalWordSenses: 0, coverage_pct: 0 };
  }
}

// ── Exam analytics ────────────────────────────────────────────────────────────
// Fields: total_attempts, pass_rate_pct, avg_score_pct (used by exam/page.tsx)

export async function getExamAnalytics(
  _intervalDays?: number,
): Promise<{
  total_attempts: number;
  pass_rate_pct: number;
  avg_score_pct: number;
}> {
  try {
    const result = await getPool().query<{
      total: string;
      pass_rate: string;
      avg_score: string;
    }>(
      `SELECT
         COUNT(*)::text AS total,
         CASE WHEN COUNT(*) = 0 THEN '0'
              ELSE (SUM(CASE WHEN passed = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*))::text
         END AS pass_rate,
         COALESCE(AVG(score_pct), 0)::text AS avg_score
       FROM exam_attempts`,
    );
    const row = result.rows[0];
    return {
      total_attempts: toNum(row?.total),
      pass_rate_pct: Math.round(toNum(row?.pass_rate) * 10) / 10,
      avg_score_pct: Math.round(toNum(row?.avg_score) * 10) / 10,
    };
  } catch {
    return { total_attempts: 0, pass_rate_pct: 0, avg_score_pct: 0 };
  }
}

// ── Exam score distribution ───────────────────────────────────────────────────

export async function getExamScoreDistribution(
  _intervalDays?: number,
): Promise<Array<{ bucket: string; count: number }>> {
  try {
    const result = await getPool().query<{ bucket: string; count: string }>(
      `SELECT
         CASE
           WHEN score_pct < 10  THEN '0-9'
           WHEN score_pct < 20  THEN '10-19'
           WHEN score_pct < 30  THEN '20-29'
           WHEN score_pct < 40  THEN '30-39'
           WHEN score_pct < 50  THEN '40-49'
           WHEN score_pct < 60  THEN '50-59'
           WHEN score_pct < 70  THEN '60-69'
           WHEN score_pct < 80  THEN '70-79'
           WHEN score_pct < 90  THEN '80-89'
           ELSE                      '90-100'
         END AS bucket,
         COUNT(*)::text AS count
       FROM exam_attempts
       GROUP BY bucket
       ORDER BY MIN(score_pct)`,
    );
    return result.rows.map(r => ({ bucket: r.bucket, count: toNum(r.count) }));
  } catch {
    return [];
  }
}

// ── Exam per-topic breakdown ──────────────────────────────────────────────────

export async function getExamTopicBreakdown(
  _intervalDays?: number,
): Promise<
  Array<{ topic: string; language: string; attempts: number; passRate: number; avgScore: number }>
> {
  try {
    const result = await getPool().query<{
      topic: string;
      language: string;
      attempts: string;
      pass_rate: string;
      avg_score: string;
    }>(
      `SELECT
         topic,
         language,
         COUNT(*)::text AS attempts,
         (SUM(CASE WHEN passed = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*))::text AS pass_rate,
         AVG(score_pct)::text AS avg_score
       FROM exam_attempts
       GROUP BY topic, language
       ORDER BY attempts DESC`,
    );
    return result.rows.map(r => ({
      topic: r.topic,
      language: r.language,
      attempts: toNum(r.attempts),
      passRate: Math.round(toNum(r.pass_rate) * 10) / 10,
      avgScore: Math.round(toNum(r.avg_score) * 10) / 10,
    }));
  } catch {
    return [];
  }
}

// ── SRS status distribution ───────────────────────────────────────────────────
// Returns object with keys: new, learning, review, completed (used by srs/page.tsx)

export async function getSrsStatusDistribution(): Promise<{
  new: number;
  learning: number;
  review: number;
  completed: number;
  [key: string]: number;
}> {
  try {
    const result = await getPool().query<{ status: string; count: string }>(
      `SELECT status, COUNT(*)::text AS count
       FROM user_word_states
       GROUP BY status`,
    );
    const map: Record<string, number> = {};
    for (const r of result.rows) {
      map[r.status] = toNum(r.count);
    }
    return {
      new: map['new'] ?? 0,
      learning: map['learning'] ?? 0,
      review: map['review'] ?? 0,
      completed: map['completed'] ?? 0,
      ...map,
    };
  } catch {
    return { new: 0, learning: 0, review: 0, completed: 0 };
  }
}

// ── SRS overdue count ─────────────────────────────────────────────────────────
// Returns object { overdue_count } (used by srs/page.tsx as overdueData.overdue_count)

export async function getSrsOverdueCount(): Promise<{ overdue_count: number }> {
  try {
    const now = new Date().toISOString();
    const result = await getPool().query<{ cnt: string }>(
      `SELECT COUNT(*)::text AS cnt
       FROM user_word_states
       WHERE next_review_at IS NOT NULL AND next_review_at < $1`,
      [now],
    );
    return { overdue_count: toNum(result.rows[0]?.cnt) };
  } catch {
    return { overdue_count: 0 };
  }
}

// ── Workplace sentences list ──────────────────────────────────────────────────
// Field: sentence (alias for sentence_text) used by workplace-sentences/page.tsx

export async function listWorkplaceSentences(opts: {
  topic?: string | null;
  language?: string | null;
  limit?: number;
  offset?: number;
}): Promise<
  Array<{
    id: string;
    sentence: string;
    sentence_text: string;
    topic: string | null;
    language: string;
    article_id: string | null;
    article_title: string | null;
    created_at: string;
  }>
> {
  try {
    const { topic = null, language = null, limit = 50, offset = 0 } = opts;
    const cappedLimit = Math.max(1, Math.min(limit, 200));
    const result = await getPool().query<{
      id: string;
      text: string;
      topic: string | null;
      language: string;
      article_id: string | null;
      article_title: string | null;
      created_at: string;
    }>(
      `SELECT
         ws.id,
         ws.text,
         ws.topic,
         ws.language,
         MAX(aws.article_id) AS article_id,
         MAX(a.title)        AS article_title,
         ws.created_at
       FROM workplace_sentences ws
       LEFT JOIN article_workplace_sentences aws ON aws.workplace_sentence_id = ws.id
       LEFT JOIN articles a ON a.id = aws.article_id
       WHERE ($1::text IS NULL OR ws.topic = $1)
         AND ($2::text IS NULL OR ws.language = $2)
       GROUP BY ws.id, ws.text, ws.topic, ws.language, ws.created_at
       ORDER BY ws.created_at DESC
       LIMIT $3 OFFSET $4`,
      [topic, language, cappedLimit, offset],
    );
    return result.rows.map(r => ({
      id: r.id,
      sentence: r.text,
      sentence_text: r.text,
      topic: r.topic,
      language: r.language,
      article_id: r.article_id,
      article_title: r.article_title,
      created_at: r.created_at,
    }));
  } catch {
    return [];
  }
}

// ── Workplace sentences for a specific article ────────────────────────────────

export async function getArticleWorkplaceSentences(articleId: string): Promise<
  Array<{
    id: string;
    sentence_text: string;
    topic: string | null;
    language: string;
    created_at: string;
  }>
> {
  try {
    const result = await getPool().query<{
      id: string;
      text: string;
      topic: string | null;
      language: string;
      created_at: string;
    }>(
      `SELECT
         ws.id,
         ws.text,
         ws.topic,
         ws.language,
         ws.created_at
       FROM workplace_sentences ws
       JOIN article_workplace_sentences aws ON aws.workplace_sentence_id = ws.id
       WHERE aws.article_id = $1
       ORDER BY ws.created_at ASC`,
      [articleId],
    );
    return result.rows.map(r => ({
      id: r.id,
      sentence_text: r.text,
      topic: r.topic,
      language: r.language,
      created_at: r.created_at,
    }));
  } catch {
    return [];
  }
}

// ── Article processing job history ────────────────────────────────────────────

export async function getArticleProcessingJobs(articleId: string): Promise<
  Array<{
    id: string;
    status: string;
    attempt_number: number;
    started_at: string | null;
    finished_at: string | null;
    duration_seconds: number | null;
    error_message: string | null;
    created_at: string;
  }>
> {
  try {
    const result = await getPool().query<{
      id: string;
      status: string;
      attempt_count: number;
      started_at: string | null;
      finished_at: string | null;
      error_message: string | null;
      created_at: string;
    }>(
      `SELECT id, status, attempt_count, started_at, finished_at, error_message, created_at
       FROM article_processing_jobs
       WHERE article_id = $1
       ORDER BY created_at DESC`,
      [articleId],
    );
    return result.rows.map(r => ({
      id: r.id,
      status: r.status,
      attempt_number: r.attempt_count,
      started_at: r.started_at,
      finished_at: r.finished_at,
      duration_seconds:
        r.started_at && r.finished_at
          ? Math.round(
              (new Date(r.finished_at).getTime() - new Date(r.started_at).getTime()) / 1000,
            )
          : null,
      error_message: r.error_message,
      created_at: r.created_at,
    }));
  } catch {
    return [];
  }
}

// ── Content coverage: word count by topic ─────────────────────────────────────
// Returns object with .rows array plus .total_topics and .total_words properties

type TopicCoverageResult = {
  rows: Array<{ topic: string; count: number }>;
  total_topics: number;
  total_words: number;
};

export async function getWordTopicCoverage(): Promise<TopicCoverageResult> {
  try {
    // topics_json is stored as a JSON text array, e.g. '["finance","tech"]'
    const [topicsResult, totalResult] = await Promise.all([
      getPool().query<{ topic: string; count: string }>(
        `SELECT
           topic_elem AS topic,
           COUNT(*)::text AS count
         FROM words,
              LATERAL jsonb_array_elements_text(topics_json::jsonb) AS topic_elem
         GROUP BY topic_elem
         ORDER BY count DESC`,
      ),
      getPool().query<{ total: string }>(
        `SELECT COUNT(*)::text AS total FROM words`,
      ),
    ]);
    const rows = topicsResult.rows.map(r => ({ topic: r.topic, count: toNum(r.count) }));
    return {
      rows,
      total_topics: rows.length,
      total_words: toNum(totalResult.rows[0]?.total),
    };
  } catch {
    return { rows: [], total_topics: 0, total_words: 0 };
  }
}

// ── Entry type distribution ───────────────────────────────────────────────────
// Field name: type (used by content/page.tsx as e.type)

export async function getEntryTypeDistribution(): Promise<
  Array<{ type: string; entry_type: string; count: number }>
> {
  try {
    const result = await getPool().query<{ entry_type: string; count: string }>(
      `SELECT entry_type, COUNT(*)::text AS count
       FROM words
       GROUP BY entry_type
       ORDER BY count DESC`,
    );
    return result.rows.map(r => ({
      type: r.entry_type,
      entry_type: r.entry_type,
      count: toNum(r.count),
    }));
  } catch {
    return [];
  }
}

// ── Quality score histogram ───────────────────────────────────────────────────
// Returns object with .rows array plus .avg_score

type QualityHistogramResult = {
  rows: Array<{ bucket: string; count: number }>;
  avg_score: number | null;
};

export async function getQualityScoreHistogram(): Promise<QualityHistogramResult> {
  try {
    const [histResult, avgResult] = await Promise.all([
      getPool().query<{ bucket: string; count: string }>(
        `SELECT
           CASE
             WHEN quality_score IS NULL THEN 'unscored'
             WHEN quality_score < 0.1   THEN '0.0-0.1'
             WHEN quality_score < 0.2   THEN '0.1-0.2'
             WHEN quality_score < 0.3   THEN '0.2-0.3'
             WHEN quality_score < 0.4   THEN '0.3-0.4'
             WHEN quality_score < 0.5   THEN '0.4-0.5'
             WHEN quality_score < 0.6   THEN '0.5-0.6'
             WHEN quality_score < 0.7   THEN '0.6-0.7'
             WHEN quality_score < 0.8   THEN '0.7-0.8'
             WHEN quality_score < 0.9   THEN '0.8-0.9'
             ELSE                            '0.9-1.0'
           END AS bucket,
           COUNT(*)::text AS count
         FROM word_senses
         GROUP BY bucket
         ORDER BY MIN(COALESCE(quality_score, -1))`,
      ),
      getPool().query<{ avg: string | null }>(
        `SELECT AVG(quality_score)::text AS avg FROM word_senses WHERE quality_score IS NOT NULL`,
      ),
    ]);
    const rows = histResult.rows.map(r => ({ bucket: r.bucket, count: toNum(r.count) }));
    const avg = avgResult.rows[0]?.avg != null ? Number(avgResult.rows[0].avg) : null;
    return { rows, avg_score: avg };
  } catch {
    return { rows: [], avg_score: null };
  }
}

// ── Daily vocabulary review throughput ────────────────────────────────────────

export async function getVocabReviewThroughput(
  intervalDays: number,
): Promise<Array<{ date: string; approved: number; rejected: number }>> {
  try {
    const since = new Date(Date.now() - intervalDays * 86400_000)
      .toISOString()
      .slice(0, 10);
    const result = await getPool().query<{
      date: string;
      approved: string;
      rejected: string;
    }>(
      `SELECT
         SUBSTRING(reviewed_at, 1, 10) AS date,
         SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END)::text AS approved,
         SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END)::text AS rejected
       FROM vocabulary_review_items
       WHERE reviewed_at IS NOT NULL AND reviewed_at >= $1
       GROUP BY SUBSTRING(reviewed_at, 1, 10)
       ORDER BY date ASC`,
      [since],
    );
    return result.rows.map(r => ({
      date: r.date,
      approved: toNum(r.approved),
      rejected: toNum(r.rejected),
    }));
  } catch {
    return [];
  }
}

// ── User SRS word states ──────────────────────────────────────────────────────

export async function getUserSrsStates(userId: string): Promise<
  Array<{
    word_id: string;
    term: string | null;
    status: string;
    ease_factor: number | null;
    review_count: number;
    next_review_at: string | null;
  }>
> {
  try {
    const result = await getPool().query<{
      word_id: string;
      term: string | null;
      status: string;
      ease_factor: number | null;
      review_count: number;
      next_review_at: string | null;
    }>(
      `SELECT
         uws.word_id,
         w.term,
         uws.status,
         uws.ease_factor,
         uws.review_count,
         uws.next_review_at
       FROM user_word_states uws
       LEFT JOIN words w ON w.id = uws.word_id
       WHERE uws.user_id = $1
       ORDER BY uws.next_review_at ASC NULLS LAST`,
      [userId],
    );
    return result.rows;
  } catch {
    return [];
  }
}

// ── User speaking stats ───────────────────────────────────────────────────────

export async function getUserSpeakingStats(userId: string): Promise<{
  totalEvents: number;
  drillsCompleted: number;
  lastSpeakingAt: string | null;
  selfRatingDistribution: Array<{ rating: string; count: number }>;
}> {
  try {
    const [summary, ratings] = await Promise.all([
      getPool().query<{
        total: string;
        drills: string;
        last_at: string | null;
      }>(
        `SELECT
           COUNT(*)::text AS total,
           SUM(CASE WHEN event_type = 'speaking_drill_completed' THEN 1 ELSE 0 END)::text AS drills,
           MAX(occurred_at) AS last_at
         FROM speaking_events
         WHERE user_id = $1`,
        [userId],
      ),
      getPool().query<{ rating: string; count: string }>(
        `SELECT self_rating AS rating, COUNT(*)::text AS count
         FROM speaking_events
         WHERE user_id = $1 AND self_rating IS NOT NULL
         GROUP BY self_rating
         ORDER BY count DESC`,
        [userId],
      ),
    ]);
    const row = summary.rows[0];
    return {
      totalEvents: toNum(row?.total),
      drillsCompleted: toNum(row?.drills),
      lastSpeakingAt: row?.last_at ?? null,
      selfRatingDistribution: ratings.rows.map(r => ({
        rating: r.rating,
        count: toNum(r.count),
      })),
    };
  } catch {
    return {
      totalEvents: 0,
      drillsCompleted: 0,
      lastSpeakingAt: null,
      selfRatingDistribution: [],
    };
  }
}

// ── User exam history ─────────────────────────────────────────────────────────

export async function getUserExamHistory(userId: string): Promise<
  Array<{
    id: string;
    topic: string;
    language: string;
    score_pct: number;
    passed: boolean;
    created_at: string;
    certificate_id: string | null;
  }>
> {
  try {
    const result = await getPool().query<{
      id: string;
      topic: string;
      language: string;
      score_pct: number;
      passed: number;
      created_at: string;
      certificate_id: string | null;
    }>(
      `SELECT
         ea.id,
         ea.topic,
         ea.language,
         ea.score_pct,
         ea.passed,
         ea.created_at,
         ec.id AS certificate_id
       FROM exam_attempts ea
       LEFT JOIN exam_certificates ec ON ec.attempt_id = ea.id
       WHERE ea.user_id = $1
       ORDER BY ea.created_at DESC`,
      [userId],
    );
    return result.rows.map(r => ({
      id: r.id,
      topic: r.topic,
      language: r.language,
      score_pct: r.score_pct,
      passed: r.passed === 1,
      created_at: r.created_at,
      certificate_id: r.certificate_id,
    }));
  } catch {
    return [];
  }
}
