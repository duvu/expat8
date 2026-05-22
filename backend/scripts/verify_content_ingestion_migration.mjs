import process from 'node:process';

import pg from 'pg';

const REQUIRED_TABLES = [
  'articles',
  'article_processing_jobs',
  'terms',
  'word_senses',
  'article_terms',
  'vocabulary_review_items',
  'content_packs',
  'content_pack_items',
  'speaking_prompts',
  'speaking_events'
];

const REQUIRED_INDEXES = [
  'idx_study_events_event_id',
  'idx_study_events_projection_order_device',
  'idx_study_events_projection_order_user',
  'idx_articles_owner_created',
  'idx_articles_status_created',
  'idx_article_processing_jobs_status_queued',
  'idx_word_senses_status_level',
  'idx_vocabulary_review_items_status_created',
  'idx_content_packs_language_version',
  'idx_speaking_events_client_event_id',
  'idx_speaking_prompts_word_sense_status',
  'idx_speaking_prompts_article_term',
  'idx_speaking_prompts_status_updated',
  'idx_speaking_events_device_occurred',
  'idx_speaking_events_user_occurred',
  'idx_speaking_events_prompt_occurred',
  'idx_speaking_events_attempt',
  'idx_speaking_events_device_type_occurred'
];

async function main() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }

  const pool = new pg.Pool({ connectionString: databaseUrl });
  try {
    const missingTables = await findMissingTables(pool, REQUIRED_TABLES);
    const missingIndexes = await findMissingIndexes(pool, REQUIRED_INDEXES);

    if (missingTables.length > 0 || missingIndexes.length > 0) {
      if (missingTables.length > 0) {
        console.error(`Missing tables: ${missingTables.join(', ')}`);
      }
      if (missingIndexes.length > 0) {
        console.error(`Missing indexes: ${missingIndexes.join(', ')}`);
      }
      process.exit(2);
    }

    console.log('Migration verification passed: all required tables and indexes exist.');
  } finally {
    await pool.end();
  }
}

async function findMissingTables(pool, tableNames) {
  const result = await pool.query(
    `SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public'`
  );
  const existing = new Set(result.rows.map((row) => row.tablename));
  return tableNames.filter((name) => !existing.has(name));
}

async function findMissingIndexes(pool, indexNames) {
  const result = await pool.query(
    `SELECT indexname FROM pg_catalog.pg_indexes WHERE schemaname = 'public'`
  );
  const existing = new Set(result.rows.map((row) => row.indexname));
  return indexNames.filter((name) => !existing.has(name));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
