#!/usr/bin/env node
import {
  buildCanonicalRequest,
  hashBody,
  signCanonicalRequest
} from '../backend/src/app_credentials.js';

const baseUrl = withoutTrailingSlash(
  process.env.BACKEND_BASE_URL ?? '<YOUR_BACKEND_URL>'
);
const appId = process.env.APP_CREDENTIAL_APP_ID ?? 'expat8-mobile-app';
const appSecret = process.env.APP_CREDENTIAL_SECRET ?? '<YOUR_APP_SECRET>';
const timeoutMs = Number(process.env.SMOKE_TIMEOUT_MS ?? '5000');

const checks = [];

await check('GET /health unsigned returns ok', async () => {
  const response = await timedFetch(`${baseUrl}/health`);
  assertStatus(response, 200);
  const body = await response.json();
  if (body.ok !== true) {
    throw new Error(`expected health ok=true, got ${JSON.stringify(body)}`);
  }
});

await check('GET /v1/words/recent unsigned is rejected', async () => {
  const response = await timedFetch(recentWordsUrl());
  if (response.status < 400) {
    throw new Error(`expected unsigned request rejection, got ${response.status}`);
  }
});

await check('GET /v1/words/recent signed returns items', async () => {
  const url = recentWordsUrl();
  const response = await timedFetch(url, signedFetchOptions(url));
  assertStatus(response, 200);
  const body = await response.json();
  if (!Array.isArray(body.items)) {
    throw new Error(`expected items array, got ${JSON.stringify(body)}`);
  }
});

const failed = checks.filter((result) => !result.ok);
for (const result of checks) {
  const prefix = result.ok ? 'PASS' : 'FAIL';
  console.log(`${prefix} ${result.name}${result.detail ? ` - ${result.detail}` : ''}`);
}
if (
  baseUrl.startsWith('https://') &&
  failed.length === 0 &&
  process.env.NODE_TLS_REJECT_UNAUTHORIZED !== '0'
) {
  console.log('PASS TLS certificate accepted by Node fetch for HTTPS base URL');
}
if (baseUrl.startsWith('https://') && process.env.NODE_TLS_REJECT_UNAUTHORIZED === '0') {
  console.log('SKIP TLS certificate validation because NODE_TLS_REJECT_UNAUTHORIZED=0');
}
if (failed.length > 0) {
  process.exitCode = 1;
}

async function check(name, run) {
  try {
    await run();
    checks.push({ name, ok: true });
  } catch (error) {
    checks.push({ name, ok: false, detail: errorDetail(error) });
  }
}

function errorDetail(error) {
  const cause = error.cause;
  if (cause) {
    const code = cause.code ? `${cause.code}: ` : '';
    return `${error.message}; ${code}${cause.message ?? cause}`;
  }
  return error.message;
}

function recentWordsUrl() {
  const url = new URL('/v1/words/recent', baseUrl);
  url.searchParams.set('limit', '1');
  url.searchParams.set('source_language', 'vi');
  url.searchParams.set('target_language', 'en');
  return url.toString();
}

function signedFetchOptions(url, options = {}) {
  const method = (options.method ?? 'GET').toUpperCase();
  const rawBody = rawBodyBuffer(options.body);
  const timestamp = new Date().toISOString();
  const nonce = `smoke_${Date.now()}_${Math.random().toString(16).slice(2)}`;
  const contentSha256 = hashBody(rawBody);
  const canonicalRequest = buildCanonicalRequest({
    method,
    url: new URL(url),
    timestamp,
    nonce,
    contentSha256
  });

  return {
    ...options,
    method,
    headers: {
      ...(options.headers ?? {}),
      'x-expat8-app-id': appId,
      'x-expat8-timestamp': timestamp,
      'x-expat8-nonce': nonce,
      'x-expat8-content-sha256': contentSha256,
      'x-expat8-signature': signCanonicalRequest({
        secret: appSecret,
        canonicalRequest
      })
    }
  };
}

async function timedFetch(url, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal
    });
  } finally {
    clearTimeout(timer);
  }
}

function rawBodyBuffer(body) {
  if (!body) {
    return Buffer.alloc(0);
  }
  if (Buffer.isBuffer(body)) {
    return body;
  }
  return Buffer.from(String(body));
}

function assertStatus(response, expected) {
  if (response.status !== expected) {
    throw new Error(`expected ${expected}, got ${response.status}`);
  }
}

function withoutTrailingSlash(value) {
  return value.endsWith('/') ? value.slice(0, -1) : value;
}
