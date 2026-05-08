#!/usr/bin/env node
// Generates bundled seed vocabulary JSON files by repeatedly fetching from a
// running backend until each language reaches the configured target size.
//
// Usage:
//   node scripts/generate-seed-vocabulary.mjs                  # default 1000 per language
//   TARGET_PER_LANGUAGE=500 node scripts/generate-seed-vocabulary.mjs
//   BACKEND_URL=https://expat8.x51.vn node scripts/generate-seed-vocabulary.mjs
//
// Required env (or .env.example defaults):
//   APP_ID, APP_SECRET — must match an active credential the backend trusts.
//
// Output: writes to mobile/assets/seed_vocab/<language>.json. Existing entries
// are preserved when re-running so deltas are appended rather than reshuffled.

import { createHmac, randomBytes, createHash } from 'node:crypto';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';

const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const ASSETS_DIR = path.join(REPO_ROOT, 'mobile', 'assets', 'seed_vocab');

const BACKEND_URL = (process.env.BACKEND_URL ?? 'http://localhost:8787').replace(/\/$/, '');
const APP_ID = process.env.APP_ID ?? 'expat8-mobile-app';
const APP_SECRET = process.env.APP_SECRET ?? 'expat8-mobile-secret';
const TARGET_PER_LANGUAGE = Number.parseInt(process.env.TARGET_PER_LANGUAGE ?? '1000', 10);
const LANGUAGES = (process.env.LANGUAGES ?? 'en,zh,vi').split(',').map((l) => l.trim()).filter(Boolean);
const BATCH_LIMIT = 100;
const DEVICE_ID = process.env.SEED_DEVICE_ID ?? `seed-generator-${Date.now()}`;

async function main() {
  if (!existsSync(ASSETS_DIR)) {
    await mkdir(ASSETS_DIR, { recursive: true });
  }
  for (const language of LANGUAGES) {
    await generateForLanguage(language);
  }
}

async function generateForLanguage(language) {
  const filePath = path.join(ASSETS_DIR, `${language}.json`);
  const existing = await loadExisting(filePath);
  const seenIds = new Set(existing.map((entry) => entry.server_word_id));
  const collected = [...existing];

  console.log(
    `[${language}] starting with ${existing.length} entries; target ${TARGET_PER_LANGUAGE}`
  );

  let consecutiveEmptyBatches = 0;
  while (collected.length < TARGET_PER_LANGUAGE) {
    const remaining = TARGET_PER_LANGUAGE - collected.length;
    const limit = Math.min(BATCH_LIMIT, remaining);
    const batch = await fetchLearningCards({ language, limit });
    const fresh = batch.filter((item) => !seenIds.has(item.server_word_id));
    if (fresh.length === 0) {
      consecutiveEmptyBatches += 1;
      console.warn(
        `[${language}] backend returned no new entries (${consecutiveEmptyBatches}/3); collected ${collected.length}`
      );
      if (consecutiveEmptyBatches >= 3) {
        console.warn(
          `[${language}] stopping early; backend pool may be exhausted or generation slow`
        );
        break;
      }
      // brief backoff so backend has time to generate more via the LLM
      await new Promise((resolve) => setTimeout(resolve, 1500));
      continue;
    }
    consecutiveEmptyBatches = 0;
    for (const item of fresh) {
      seenIds.add(item.server_word_id);
      collected.push(item);
    }
    console.log(
      `[${language}] fetched ${fresh.length} new entries; total ${collected.length}/${TARGET_PER_LANGUAGE}`
    );
  }

  await writeFile(filePath, `${JSON.stringify(collected, null, 2)}\n`);
  console.log(`[${language}] wrote ${collected.length} entries to ${filePath}`);
}

async function loadExisting(filePath) {
  if (!existsSync(filePath)) return [];
  const raw = await readFile(filePath, 'utf8');
  if (!raw.trim()) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

async function fetchLearningCards({ language, limit }) {
  const uri = new URL(`${BACKEND_URL}/v1/learning/cards`);
  const body = JSON.stringify({
    device_id: DEVICE_ID,
    target_language: language,
    card_mode: 'new',
    limit,
  });
  const headers = signedHeaders({
    method: 'POST',
    uri,
    body: Buffer.from(body, 'utf8'),
  });
  headers['content-type'] = 'application/json';

  const response = await fetch(uri.toString(), {
    method: 'POST',
    headers,
    body,
  });
  if (!response.ok) {
    throw new Error(`fetchLearningCards failed: ${response.status} ${await response.text()}`);
  }
  const json = await response.json();
  const items = Array.isArray(json.items) ? json.items : [];
  return items.map(toSeedEntry).filter(Boolean);
}

function toSeedEntry(item) {
  if (!item || !item.server_word_id || !item.term) return null;
  return {
    server_word_id: item.server_word_id,
    term: item.term,
    language: item.language ?? 'en',
    meaning_vi: item.meaning_vi ?? '',
    part_of_speech: item.part_of_speech ?? null,
    ipa: item.ipa ?? '',
    vietnamese_pronunciation: item.vietnamese_pronunciation ?? '',
    example: item.example ?? '',
    example_vi: item.example_vi ?? '',
    difficulty: item.difficulty ?? '',
    topics: Array.isArray(item.topics) ? item.topics : [],
    created_at: item.created_at ?? new Date().toISOString(),
  };
}

function signedHeaders({ method, uri, body }) {
  const timestamp = new Date().toISOString();
  const nonce = `seed_${randomBytes(16).toString('base64url').replace(/=+$/, '')}`;
  const contentSha256 = sha256Base64Url(body ?? Buffer.alloc(0));
  const canonicalRequest = canonicalize({ method, uri, timestamp, nonce, contentSha256 });
  const signature = `v1=${hmacBase64Url(APP_SECRET, canonicalRequest)}`;
  return {
    'x-expat8-app-id': APP_ID,
    'x-expat8-timestamp': timestamp,
    'x-expat8-nonce': nonce,
    'x-expat8-content-sha256': contentSha256,
    'x-expat8-signature': signature,
  };
}

function canonicalize({ method, uri, timestamp, nonce, contentSha256 }) {
  const sortedKeys = [...uri.searchParams.keys()].sort();
  const sortedParams = [];
  for (const key of sortedKeys) {
    const values = uri.searchParams.getAll(key).slice().sort();
    for (const value of values) {
      sortedParams.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    }
  }
  const canonicalPathWithQuery = sortedParams.length > 0
    ? `${uri.pathname}?${sortedParams.join('&')}`
    : uri.pathname;
  return [
    'v1',
    method.toUpperCase(),
    canonicalPathWithQuery,
    timestamp,
    nonce,
    contentSha256,
  ].join('\n');
}

function sha256Base64Url(buffer) {
  return createHash('sha256').update(buffer).digest('base64url').replace(/=+$/, '');
}

function hmacBase64Url(secret, payload) {
  return createHmac('sha256', secret).update(payload, 'utf8').digest('base64url').replace(/=+$/, '');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
