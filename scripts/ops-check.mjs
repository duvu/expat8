#!/usr/bin/env node
// One-shot production check for cron or manual use. Prints one line per check
// and exits 1 if any check fails.
//
//   BACKEND_BASE_URL=... APP_CREDENTIAL_APP_ID=... APP_CREDENTIAL_SECRET=... \
//   ADMIN_TOKEN=... node scripts/ops-check.mjs
//
// Optional: OPS_PENDING_THRESHOLD (default 20), OPS_STALE_MINUTES (default 60),
// OPS_TIMEOUT_MS (default 5000), OPS_GITHUB_REPO (default duvu/expat8; set to
// "" to skip the release check).
import { randomBytes } from 'node:crypto';

import { buildCanonicalRequest, hashBody, signCanonicalRequest } from '../backend/src/app_credentials.js';

const baseUrl = (process.env.BACKEND_BASE_URL ?? '').replace(/\/+$/, '');
const appId = process.env.APP_CREDENTIAL_APP_ID;
const secret = process.env.APP_CREDENTIAL_SECRET;
const adminToken = process.env.ADMIN_TOKEN;
const pendingThreshold = Number(process.env.OPS_PENDING_THRESHOLD ?? '20');
const staleMinutes = Number(process.env.OPS_STALE_MINUTES ?? '60');
const timeoutMs = Number(process.env.OPS_TIMEOUT_MS ?? '5000');
const githubRepo = process.env.OPS_GITHUB_REPO ?? 'duvu/expat8';

if (!baseUrl) {
  console.error('BACKEND_BASE_URL is required');
  process.exit(2);
}

let failed = false;
const report = (ok, name, detail) => {
  if (!ok) failed = true;
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`);
};

await run('health', async () => {
  const res = await get('/health');
  return [res.status === 200, `HTTP ${res.status}`];
});

await run('ready (database)', async () => {
  const res = await get('/health/ready');
  const body = await res.json().catch(() => ({}));
  return [res.status === 200 && body.db === 'ok', `HTTP ${res.status} ${JSON.stringify(body)}`];
});

if (appId && secret && adminToken) {
  await run('content pipeline', async () => {
    const res = await get('/v1/admin/content-pipeline/health', { signed: true, admin: true });
    if (res.status !== 200) return [false, `HTTP ${res.status}`];
    const body = await res.json();
    const problems = [];
    for (const [name, s] of Object.entries(body)) {
      if (s.failed_count > 0) problems.push(`${name}: ${s.failed_count} failed`);
      if (s.pending_count > pendingThreshold) problems.push(`${name}: ${s.pending_count} pending`);
      if (s.pending_count > 0 && s.last_processed_at) {
        const ageMin = (Date.now() - Date.parse(s.last_processed_at)) / 60000;
        if (ageMin > staleMinutes)
          problems.push(`${name}: pending but nothing processed for ${Math.round(ageMin)} min`);
      }
    }
    return [problems.length === 0, problems.join('; ') || 'no failed or stuck items'];
  });
} else {
  console.log('SKIP content pipeline — set APP_CREDENTIAL_APP_ID, APP_CREDENTIAL_SECRET and ADMIN_TOKEN');
}

if (appId && secret && githubRepo) {
  await run('in-app update matches GitHub release', async () => {
    const res = await get('/v1/releases/latest?platform=android', { signed: true });
    const backendVersion = res.status === 200 ? (await res.json()).release?.version_name : null;
    const gh = await timed(`https://api.github.com/repos/${githubRepo}/releases/latest`, {
      headers: { accept: 'application/vnd.github+json' }
    });
    if (gh.status !== 200) return [true, `GitHub HTTP ${gh.status}, not compared`];
    const githubVersion = (await gh.json()).tag_name?.replace(/^v/, '');
    return [backendVersion === githubVersion, `backend ${backendVersion ?? 'none'}, GitHub ${githubVersion}`];
  });
}

process.exit(failed ? 1 : 0);

async function run(name, fn) {
  try {
    const [ok, detail] = await fn();
    report(ok, name, detail);
  } catch (error) {
    report(false, name, error.message);
  }
}

function get(path, { signed = false, admin = false } = {}) {
  const url = new URL(baseUrl + path);
  const headers = {};
  if (signed) {
    const timestamp = new Date().toISOString();
    const nonce = `opscheck_${Date.now()}_${randomBytes(8).toString('hex')}`;
    const contentSha256 = hashBody(Buffer.alloc(0));
    Object.assign(headers, {
      'x-expat8-app-id': appId,
      'x-expat8-timestamp': timestamp,
      'x-expat8-nonce': nonce,
      'x-expat8-content-sha256': contentSha256,
      'x-expat8-signature': signCanonicalRequest({
        secret,
        canonicalRequest: buildCanonicalRequest({ method: 'GET', url, timestamp, nonce, contentSha256 })
      })
    });
  }
  if (admin) headers['x-expat8-admin-token'] = adminToken;
  return timed(url, { headers });
}

function timed(url, options) {
  return fetch(url, { ...options, signal: AbortSignal.timeout(timeoutMs) });
}
