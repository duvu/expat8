#!/usr/bin/env node
// Signed request helper for operators (admin and app endpoints).
//
//   BACKEND_BASE_URL=https://... APP_CREDENTIAL_APP_ID=... APP_CREDENTIAL_SECRET=... \
//   ADMIN_TOKEN=... node scripts/admin-request.mjs GET /v1/admin/content-pipeline/health
//
//   node scripts/admin-request.mjs POST /v1/admin/releases \
//     --file app-release.apk \
//     --header x-expat8-release-platform=android \
//     --header x-expat8-release-version-code=8 \
//     --header x-expat8-release-version-name=1.3.4
//
// Options: --json '<body>' | --file <path>, --header name=value (repeatable),
// --out <path> to save a binary response. Prints status and body to stdout;
// exits 1 on a non-2xx response.
import { readFile, writeFile } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';

import { buildCanonicalRequest, hashBody, signCanonicalRequest } from '../backend/src/app_credentials.js';

const [method, path, ...rest] = process.argv.slice(2);
if (!method || !path) {
  console.error('usage: admin-request.mjs <METHOD> <PATH> [--json BODY | --file PATH] [--header k=v]... [--out PATH]');
  process.exit(2);
}

const baseUrl = requiredEnv('BACKEND_BASE_URL').replace(/\/+$/, '');
const appId = requiredEnv('APP_CREDENTIAL_APP_ID');
const secret = requiredEnv('APP_CREDENTIAL_SECRET');

const headers = {};
let body = Buffer.alloc(0);
let outPath = null;
for (let i = 0; i < rest.length; i += 2) {
  const [flag, value] = [rest[i], rest[i + 1]];
  if (value === undefined) fail(`missing value for ${flag}`);
  if (flag === '--json') {
    body = Buffer.from(value);
    headers['content-type'] = 'application/json';
  } else if (flag === '--file') {
    body = await readFile(value);
    headers['content-type'] ??= 'application/octet-stream';
  } else if (flag === '--header') {
    const eq = value.indexOf('=');
    if (eq <= 0) fail(`bad header ${value}`);
    headers[value.slice(0, eq).toLowerCase()] = value.slice(eq + 1);
  } else if (flag === '--out') {
    outPath = value;
  } else {
    fail(`unknown option ${flag}`);
  }
}

if (process.env.ADMIN_TOKEN) headers['x-expat8-admin-token'] = process.env.ADMIN_TOKEN;
if (process.env.SESSION_TOKEN) headers.authorization = `Bearer ${process.env.SESSION_TOKEN}`;

const url = new URL(baseUrl + path);
const upper = method.toUpperCase();
const timestamp = new Date().toISOString();
const nonce = `ops_${Date.now()}_${randomBytes(8).toString('hex')}`;
const contentSha256 = hashBody(body);
const signature = signCanonicalRequest({
  secret,
  canonicalRequest: buildCanonicalRequest({ method: upper, url, timestamp, nonce, contentSha256 })
});

const response = await fetch(url, {
  method: upper,
  headers: {
    ...headers,
    'x-expat8-app-id': appId,
    'x-expat8-timestamp': timestamp,
    'x-expat8-nonce': nonce,
    'x-expat8-content-sha256': contentSha256,
    'x-expat8-signature': signature
  },
  body: upper === 'GET' || upper === 'HEAD' ? undefined : body
});

console.log(`HTTP ${response.status}`);
if (outPath) {
  await writeFile(outPath, Buffer.from(await response.arrayBuffer()));
  console.log(`saved ${outPath}`);
} else {
  const text = await response.text();
  try {
    console.log(JSON.stringify(JSON.parse(text), null, 2));
  } catch {
    console.log(text);
  }
}
process.exit(response.ok ? 0 : 1);

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) fail(`${name} is required`);
  return value;
}

function fail(message) {
  console.error(message);
  process.exit(2);
}
