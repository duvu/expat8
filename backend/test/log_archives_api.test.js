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

  const emptyUpload = await fetch(
    uploadUrl,
    signedFetchOptions(uploadUrl, {
      method: 'POST',
      headers: { 'content-type': 'text/plain; charset=utf-8' },
      body: ''
    })
  );
  assert.equal(emptyUpload.status, 400);

  const invalidSessionUpload = await fetch(
    uploadUrl,
    signedFetchOptions(uploadUrl, {
      method: 'POST',
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        authorization: 'Bearer invalid-session-token'
      },
      body: 'logs with invalid session'
    })
  );
  assert.equal(invalidSessionUpload.status, 401);

  const registered = store.registerUser({
    identifier: 'logs-user@example.com',
    password: 'correct-password',
    deviceId: 'device-123'
  });
  const payload = 'hello from logs\nsecond line\nxin chào\n';

  const upload = await fetch(
    uploadUrl,
    signedFetchOptions(uploadUrl, {
      method: 'POST',
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'x-expat8-device-id': 'device-123',
        'x-expat8-log-source': 'mobile',
        'x-expat8-log-filename': 'app.log',
        authorization: `Bearer ${registered.sessionToken}`
      },
      body: payload
    })
  );
  assert.equal(upload.status, 201);

  const uploaded = await upload.json();
  assert.equal(uploaded.file_name, 'app.log');
  assert.equal(uploaded.size_bytes, Buffer.byteLength(payload));
  assert.equal(uploaded.source_device_id, 'device-123');
  assert.equal(uploaded.source_user_id, registered.user.id);
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
  assert.equal(await contentResponse.text(), payload);

  const downloadResponse = await fetch(
    `${baseUrl}/v1/admin/log-archives/${uploaded.id}/download`,
    signedFetchOptions(`${baseUrl}/v1/admin/log-archives/${uploaded.id}/download`, {
      headers: { 'x-expat8-admin-token': 'admin-token' }
    })
  );
  assert.equal(downloadResponse.status, 200);
  assert.match(downloadResponse.headers.get('content-disposition') ?? '', /attachment/);
  assert.equal(await downloadResponse.text(), payload);

  // DELETE — missing token → 403
  const deleteNoToken = await fetch(
    `${baseUrl}/v1/admin/log-archives/${uploaded.id}`,
    signedFetchOptions(`${baseUrl}/v1/admin/log-archives/${uploaded.id}`, { method: 'DELETE' })
  );
  assert.equal(deleteNoToken.status, 403);

  // DELETE — not found → 404
  const deleteNotFound = await fetch(
    `${baseUrl}/v1/admin/log-archives/nonexistent-id`,
    signedFetchOptions(`${baseUrl}/v1/admin/log-archives/nonexistent-id`, {
      method: 'DELETE',
      headers: { 'x-expat8-admin-token': 'admin-token' }
    })
  );
  assert.equal(deleteNotFound.status, 404);

  // DELETE — success → 204
  const deleteOk = await fetch(
    `${baseUrl}/v1/admin/log-archives/${uploaded.id}`,
    signedFetchOptions(`${baseUrl}/v1/admin/log-archives/${uploaded.id}`, {
      method: 'DELETE',
      headers: { 'x-expat8-admin-token': 'admin-token' }
    })
  );
  assert.equal(deleteOk.status, 204);

  // Archive is gone from the list
  const listAfterDelete = await fetchJson(listUrl, {
    headers: { 'x-expat8-admin-token': 'admin-token' }
  });
  assert.equal(listAfterDelete.items.length, 0);

  // DELETE again → 404
  const deleteAgain = await fetch(
    `${baseUrl}/v1/admin/log-archives/${uploaded.id}`,
    signedFetchOptions(`${baseUrl}/v1/admin/log-archives/${uploaded.id}`, {
      method: 'DELETE',
      headers: { 'x-expat8-admin-token': 'admin-token' }
    })
  );
  assert.equal(deleteAgain.status, 404);
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
