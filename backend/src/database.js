import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = dirname(fileURLToPath(import.meta.url));
const defaultSchemaPath = resolve(currentDir, '../db/schema.sql');

export function readSchemaSql({ schemaPath = defaultSchemaPath } = {}) {
  return readFileSync(schemaPath, 'utf8');
}

export async function initializeDatabaseSchema({ pool, schemaSql = readSchemaSql() }) {
  await pool.query(schemaSql);
}
