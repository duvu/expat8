import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { FileLogArchiveStore } from '../src/log_archive_store.js';

test('FileLogArchiveStore evicts oldest archives when size exceeds the cap', async () => {
  const rootDir = await mkdtemp(path.join(os.tmpdir(), 'expat8-log-archives-'));
  const store = new FileLogArchiveStore({
    rootDir,
    retentionDays: 30,
    maxTotalBytes: 15
  });

  await store.saveArchive({
    appId: 'app_mobile_test',
    body: Buffer.from('abcdefghij'),
    uploadedAt: new Date('2026-05-01T00:00:00.000Z'),
    now: new Date('2026-05-04T00:00:00.000Z')
  });
  await store.saveArchive({
    appId: 'app_mobile_test',
    body: Buffer.from('klmnopqrst'),
    uploadedAt: new Date('2026-05-02T00:00:00.000Z'),
    now: new Date('2026-05-04T00:00:00.000Z')
  });
  await store.saveArchive({
    appId: 'app_mobile_test',
    body: Buffer.from('uvwxy'),
    uploadedAt: new Date('2026-05-03T00:00:00.000Z'),
    now: new Date('2026-05-04T00:00:00.000Z')
  });

  const archives = await store.listArchives({ limit: 10, now: new Date('2026-05-04T00:00:00.000Z') });

  assert.equal(archives.length, 2);
  assert.deepEqual(
    archives.map((archive) => archive.uploadedAt),
    ['2026-05-03T00:00:00.000Z', '2026-05-02T00:00:00.000Z']
  );

  await rm(rootDir, { recursive: true, force: true });
});

test('FileLogArchiveStore removes archives older than the retention window', async () => {
  const rootDir = await mkdtemp(path.join(os.tmpdir(), 'expat8-log-archives-'));
  const store = new FileLogArchiveStore({
    rootDir,
    retentionDays: 3,
    maxTotalBytes: 1024
  });

  await store.saveArchive({
    appId: 'app_mobile_test',
    body: Buffer.from('stale archive'),
    uploadedAt: new Date('2026-05-01T00:00:00.000Z'),
    now: new Date('2026-05-05T00:00:00.000Z')
  });

  const archives = await store.listArchives({ limit: 10, now: new Date('2026-05-05T00:00:00.000Z') });
  assert.equal(archives.length, 0);

  await rm(rootDir, { recursive: true, force: true });
});
