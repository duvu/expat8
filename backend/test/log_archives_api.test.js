import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { createApp } from '../src/app.js';
import { WordStore } from '../src/word_store.js';
import { loadTestConfig, signedFetchOptions } from './support/app_credential_helpers.js';

test('mobile log uploads require app credentials and are browsable by admins', async (t) => {
  const rootDir = await mkdtemp(path.join(os.tmpdir(), 'expat8-log-api-'));
  const store = new WordStore({ seed: false });
  const server = http.createServer(
    createApp({
      store,
      generationService: null,
      config: loadTestConfig({
        ADMIN_API_TOKENS: 'admin-token',
        LOG_ARCHIVE_DIR: rootDir,
        LOG_ARCHIVE_UPLOAD_BODY_LIMIT_BYTES: '1048576',
        LOG_ARCHIVE_MAX_TOTAL_BYTES: '1048576'
      })
    })
  );
  await listen(server);
  t.after(async () => {
    server.close();
    await rm(rootDir, { recursive: true, force: true });
  });

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const uploadUrl = `${baseUrl}/v1/mobile/log-archives`;
  const unsigned = await fetch(uploadUrl, {
    method: 'POST',
    headers: { 'content-type': 'text/plain; charset=utf-8' },
    body: 'hello from logs'
  });
  assert.equal(unsigned.status, 400);

  const upload = await fetch(uploadUrl, signedFetchOptions(uploadUrl, {
    method: 'POST',
    headers: {
      'content-type': 'text/plain; charset=utf-8',
      'x-expat8-device-id': 'device-123',
      'x-expat8-log-source': 'mobile',
      'x-expat8-log-filename': 'app.log'
    },
    body: 'hello from logs\nsecond line\n'
  }));
  assert.equal(upload.status, 201);

  const uploaded = await upload.json();
  assert.equal(uploaded.file_name, 'app.log');
  assert.equal(uploaded.size_bytes, 'hello from logs\nsecond line\n'.length);
  assert.equal(uploaded.source_device_id, 'device-123');
  assert.equal(uploaded.source_app_id, 'app_mobile_test');

  const listUrl = `${baseUrl}/v1/admin/log-archives?limit=10`;
  const list = await fetchJson(listUrl, {
    headers: { 'x-expat8-admin-token': 'admin-token' }
  });
  assert.equal(list.items.length, 1);
  assert.equal(list.items[0].file_name, 'app.log');
  assert.equal(list.items[0].retention_state, 'active');

  const detailUrl = `${baseUrl}/v1/admin/log-archives/${uploaded.id}`;
  const detail = await fetchJson(detailUrl, {
    headers: { 'x-expat8-admin-token': 'admin-token' }
  });
  assert.equal(detail.id, uploaded.id);
  assert.equal(detail.download_url, `/v1/admin/log-archives/${uploaded.id}/download`);

  const contentResponse = await fetch(
    `${baseUrl}/v1/admin/log-archives/${uploaded.id}/content`,
    signedFetchOptions(`${baseUrl}/v1/admin/log-archives/${uploaded.id}/content`, {
      headers: { 'x-expat8-admin-token': 'admin-token' }
    })
  );
  assert.equal(contentResponse.status, 200);
  assert.equal(await contentResponse.text(), 'hello from logs\nsecond line\n');

  const downloadResponse = await fetch(
    `${baseUrl}/v1/admin/log-archives/${uploaded.id}/download`,
    signedFetchOptions(`${baseUrl}/v1/admin/log-archives/${uploaded.id}/download`, {
      headers: { 'x-expat8-admin-token': 'admin-token' }
    })
  );
  assert.equal(downloadResponse.status, 200);
  assert.match(downloadResponse.headers.get('content-disposition') ?? '', /attachment/);
  assert.equal(await downloadResponse.text(), 'hello from logs\nsecond line\n');
});

async function listen(server) {
  return new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, signedFetchOptions(url, options));
  if (!response.ok) {
    assert.fail(`${response.status} ${await response.text()}`);
  }
  return response.json();
}
