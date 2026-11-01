// Bulk-import vocabulary JSON files (the API/seed word shape) into the `words` table.
//   npm run import:words -- --dir data/zh_hsk [--dry-run]
// Idempotent: a word whose (language, normalized_term) already exists is left untouched.
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import pg from 'pg';

import { loadConfig } from './config.js';
import { createLogger } from './logger.js';
import { PostgresWordStore } from './postgres_word_store.js';
import { validateVocabularyItem } from './vocabulary_validator.js';

export const IMPORT_GENERATION_SOURCE = 'import';

/** Reads every `*.json` file of `dir` (sorted by name); each must hold an array of words. */
export async function readWordFiles(dir) {
  const names = (await readdir(dir)).filter((name) => name.endsWith('.json')).sort();
  if (names.length === 0) {
    throw new Error(`no .json files in ${dir}`);
  }
  const files = [];
  for (const name of names) {
    const words = JSON.parse(await readFile(path.join(dir, name), 'utf8'));
    if (!Array.isArray(words)) {
      throw new Error(`${name} must contain a JSON array`);
    }
    files.push({ name, words });
  }
  return files;
}

/**
 * Validates and inserts the words of `files` through `store.insertWord`.
 * Invalid words are reported and skipped; with `dryRun` nothing is written
 * (valid words are counted as `valid`, because presence is not looked up).
 */
export async function importWords({ store, files, dryRun = false, logger }) {
  const summary = { dry_run: dryRun, total: 0, inserted: 0, existing: 0, valid: 0, invalid: 0, by_level: {} };

  for (const { name, words } of files) {
    for (const word of words) {
      summary.total += 1;
      const level = String(word.difficulty ?? 'unknown');
      const counts = (summary.by_level[level] ??= { inserted: 0, existing: 0, valid: 0, invalid: 0 });

      const verdict = validateVocabularyItem(word);
      if (!verdict.ok) {
        summary.invalid += 1;
        counts.invalid += 1;
        logger.warn('words.import.invalid', { file: name, term: word.term, reason: verdict.reason });
        continue;
      }
      if (dryRun) {
        summary.valid += 1;
        counts.valid += 1;
        continue;
      }
      const { inserted } = await store.insertWord({ generation_source: IMPORT_GENERATION_SOURCE, ...word });
      const key = inserted ? 'inserted' : 'existing';
      summary[key] += 1;
      counts[key] += 1;
    }
  }
  return summary;
}

export function parseArgs(argv) {
  const args = { dir: null, dryRun: false };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--dir') {
      args.dir = argv[(i += 1)] ?? null;
    } else if (argv[i] === '--dry-run') {
      args.dryRun = true;
    } else {
      throw new Error(`unknown argument: ${argv[i]}`);
    }
  }
  if (!args.dir) {
    throw new Error('usage: npm run import:words -- --dir <directory> [--dry-run]');
  }
  return args;
}

async function main() {
  const config = loadConfig();
  const logger = createLogger({
    level: config.logLevel,
    redactionEnabled: config.logRedactionEnabled,
    component: 'import_words'
  });

  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (error) {
    logger.error('words.import.bad_arguments', { error: error.message });
    process.exit(1);
  }
  if (!config.databaseUrl && !args.dryRun) {
    logger.error('words.import.no_database_url', {});
    process.exit(1);
  }

  const pool = args.dryRun ? null : new pg.Pool({ connectionString: config.databaseUrl, max: 2 });
  try {
    const files = await readWordFiles(args.dir);
    const store = pool ? new PostgresWordStore({ pool, logger }) : null;
    const summary = await importWords({ store, files, dryRun: args.dryRun, logger });
    logger.info('words.import.complete', summary);
  } catch (error) {
    logger.error('words.import.failed', { error: error.message });
    process.exitCode = 1;
  } finally {
    await pool?.end();
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
