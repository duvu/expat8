import pg from 'pg';

import { getAdminConfig } from './config';
import type { AdminArticle, VocabularyReviewItem } from '../types';

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
