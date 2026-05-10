import pg from 'pg';

import { getAdminConfig } from './config';
import type { AdminArticle, ExamResult, SpeakingPrompt, VocabularyReviewItem } from '../types';

type ArticleRow = {
  id: string;
  title: string;
  source_url: string | null;
  language: string;
  visibility: string;
  status: string;
  processing_error: string | null;
  created_at: string;
  updated_at: string;
};

type VocabularyRow = {
  id: string;
  status: string;
  review_note: string | null;
  reviewed_at: string | null;
  created_at: string;
  article_id: string | null;
  article_title: string | null;
  display_term: string | null;
  meaning_vi: string | null;
  example: string | null;
  example_vi: string | null;
  part_of_speech: string | null;
  ipa: string | null;
};

type SpeakingPromptRow = {
  id: string;
  word_sense_id: string;
  article_term_id: string | null;
  target_text: string | null;
  vi_hint: string | null;
  target_phrase: string | null;
  pronunciation_tip_vi: string | null;
  common_mistake_vi: string | null;
  difficulty: string | null;
  topic: string | null;
  status: string;
  reviewer_user_id: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
  display_term: string | null;
  meaning_vi: string | null;
};

let pool: pg.Pool | null = null;

function getPool() {
  const config = getAdminConfig();
  if (!config.databaseUrl) {
    throw new Error('EXPAT8_DASHBOARD_DATABASE_URL, WEB_ADMIN_DATABASE_URL, or DATABASE_URL is required');
  }
  if (!pool) {
    pool = new pg.Pool({ connectionString: config.databaseUrl });
  }
  return pool;
}

export async function listAdminArticles({ status = null, limit = 50 }: { status?: string | null; limit?: number } = {}) {
  const result = await getPool().query<ArticleRow>(
    `SELECT *
     FROM articles
     WHERE ($1::text IS NULL OR status = $1)
     ORDER BY created_at DESC
     LIMIT $2`,
    [status, Math.max(1, Math.min(limit, 100))]
  );
  return result.rows.map(mapArticleRow);
}

export async function getAdminArticle(articleId: string) {
  const result = await getPool().query<ArticleRow>(
    `SELECT * FROM articles WHERE id = $1 LIMIT 1`,
    [articleId]
  );
  return result.rows[0] ? mapArticleRow(result.rows[0]) : null;
}

export async function listArticleVocabulary(articleId: string) {
  const result = await getPool().query<VocabularyRow>(
    `SELECT
       vocabulary_review_items.id,
       vocabulary_review_items.status,
       vocabulary_review_items.review_note,
       vocabulary_review_items.reviewed_at,
       vocabulary_review_items.created_at,
       articles.id AS article_id,
       articles.title AS article_title,
       terms.display_term,
       word_senses.meaning_vi,
       article_terms.surface_text AS example,
       article_terms.sentence_context AS example_vi,
       word_senses.part_of_speech,
       word_senses.ipa
     FROM vocabulary_review_items
     JOIN word_senses ON word_senses.id = vocabulary_review_items.word_sense_id
     JOIN terms ON terms.id = word_senses.term_id
     LEFT JOIN articles ON articles.id = vocabulary_review_items.article_id
     LEFT JOIN article_terms ON article_terms.article_id = articles.id AND article_terms.word_sense_id = word_senses.id
     WHERE vocabulary_review_items.article_id = $1
     ORDER BY vocabulary_review_items.created_at DESC`,
    [articleId]
  );

  return result.rows.map(mapVocabularyRow);
}

export async function listPendingVocabulary(limit = 100) {
  const result = await getPool().query<VocabularyRow>(
    `SELECT
       vocabulary_review_items.id,
       vocabulary_review_items.status,
       vocabulary_review_items.review_note,
       vocabulary_review_items.reviewed_at,
       vocabulary_review_items.created_at,
       articles.id AS article_id,
       articles.title AS article_title,
       terms.display_term,
       word_senses.meaning_vi,
       article_terms.surface_text AS example,
       article_terms.sentence_context AS example_vi,
       word_senses.part_of_speech,
       word_senses.ipa
     FROM vocabulary_review_items
     JOIN word_senses ON word_senses.id = vocabulary_review_items.word_sense_id
     JOIN terms ON terms.id = word_senses.term_id
     LEFT JOIN articles ON articles.id = vocabulary_review_items.article_id
     LEFT JOIN article_terms ON article_terms.article_id = articles.id AND article_terms.word_sense_id = word_senses.id
     WHERE vocabulary_review_items.status = 'pending'
     ORDER BY vocabulary_review_items.created_at DESC
     LIMIT $1`,
    [Math.max(1, Math.min(limit, 200))]
  );

  return result.rows.map(mapVocabularyRow);
}

function mapArticleRow(row: ArticleRow): AdminArticle {
  return {
    id: row.id,
    title: row.title,
    source_url: row.source_url,
    language: row.language,
    visibility: row.visibility,
    status: row.status,
    processing_error: row.processing_error,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function mapVocabularyRow(row: VocabularyRow): VocabularyReviewItem {
  return {
    id: row.id,
    status: row.status,
    review_note: row.review_note,
    reviewed_at: row.reviewed_at,
    created_at: row.created_at,
    article_id: row.article_id,
    article_title: row.article_title,
    display_term: row.display_term,
    meaning_vi: row.meaning_vi,
    example: row.example,
    example_vi: row.example_vi,
    part_of_speech: row.part_of_speech,
    ipa: row.ipa
  };
}

export async function listSpeakingPrompts({
  status = null,
  missingRequired = false,
  limit = 100
}: {
  status?: string | null;
  missingRequired?: boolean;
  limit?: number;
} = {}) {
  const cappedLimit = Math.max(1, Math.min(limit, 200));
  const missingClause = missingRequired
    ? `AND (sp.target_text IS NULL OR sp.target_text = '' OR sp.vi_hint IS NULL OR sp.vi_hint = '')`
    : '';
  const result = await getPool().query<SpeakingPromptRow>(
    `SELECT
       sp.*,
       t.display_term,
       ws.meaning_vi
     FROM speaking_prompts sp
     JOIN word_senses ws ON ws.id = sp.word_sense_id
     JOIN terms t ON t.id = ws.term_id
     WHERE ($1::text IS NULL OR sp.status = $1)
     ${missingClause}
     ORDER BY sp.updated_at DESC
     LIMIT $2`,
    [status, cappedLimit]
  );
  return result.rows.map(mapSpeakingPromptRow);
}

function mapSpeakingPromptRow(row: SpeakingPromptRow): SpeakingPrompt {
  return {
    id: row.id,
    word_sense_id: row.word_sense_id,
    article_term_id: row.article_term_id,
    target_text: row.target_text,
    vi_hint: row.vi_hint,
    target_phrase: row.target_phrase,
    pronunciation_tip_vi: row.pronunciation_tip_vi,
    common_mistake_vi: row.common_mistake_vi,
    difficulty: row.difficulty,
    topic: row.topic,
    status: row.status,
    reviewer_user_id: row.reviewer_user_id,
    reviewed_at: row.reviewed_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
    display_term: row.display_term,
    meaning_vi: row.meaning_vi
  };
}

type ExamResultRow = {
  id: string;
  user_id: string;
  topic: string;
  language: string;
  difficulty_level: string | null;
  total_questions: number;
  correct_count: number;
  score_pct: number;
  passed: number;
  created_at: string;
  certificate_id: string | null;
};

export async function listExamResults({
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
  const cappedLimit = Math.max(1, Math.min(limit, 500));
  const result = await getPool().query<ExamResultRow>(
    `SELECT
       ea.id,
       ea.user_id,
       ea.topic,
       ea.language,
       ea.difficulty_level,
       ea.total_questions,
       ea.correct_count,
       ea.score_pct,
       ea.passed,
       ea.created_at,
       ec.id AS certificate_id
     FROM exam_attempts ea
     LEFT JOIN exam_certificates ec ON ec.attempt_id = ea.id
     WHERE ($1::text IS NULL OR ea.user_id = $1)
       AND ($2::text IS NULL OR ea.topic = $2)
       AND ($3::text IS NULL OR ea.language = $3)
     ORDER BY ea.created_at DESC
     LIMIT $4`,
    [userId, topic, language, cappedLimit]
  );
  return result.rows.map(mapExamResultRow);
}

function mapExamResultRow(row: ExamResultRow): ExamResult {
  return {
    id: row.id,
    user_id: row.user_id,
    topic: row.topic,
    language: row.language,
    difficulty_level: row.difficulty_level,
    total_questions: row.total_questions,
    correct_count: row.correct_count,
    score_pct: row.score_pct,
    passed: row.passed,
    created_at: row.created_at,
    certificate_id: row.certificate_id
  };
}
