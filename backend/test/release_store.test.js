import assert from 'node:assert/strict';
import { mkdtemp, rm, stat } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { ReleaseStore } from '../src/release_store.js';

async function createTempStore(options = {}) {
  const storageDir = await mkdtemp(path.join(os.tmpdir(), 'expat8-releases-'));
  const store = new ReleaseStore({ storageDir, ...options });
  return { store, storageDir };
}

test('ReleaseStore createRelease stores APK and returns metadata', async () => {
  const { store, storageDir } = await createTempStore();
  const apkBuffer = Buffer.from('fake-apk-content-here');

  const release = await store.createRelease({
    platform: 'android',
    versionCode: 1,
    versionName: '1.0.0',
    apkBuffer
  });

  assert.ok(release.id);
  assert.equal(release.platform, 'android');
  assert.equal(release.version_code, 1);
  assert.equal(release.version_name, '1.0.0');
  assert.equal(release.file_size_bytes, apkBuffer.length);
  assert.ok(release.sha256);
  assert.ok(release.created_at);
  assert.ok(release.apk_path);

  // Verify file exists on disk
  const fileStat = await stat(release.apk_path);
  assert.equal(fileStat.size, apkBuffer.length);

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore getLatestRelease returns highest version_code for platform', async () => {
  const { store, storageDir } = await createTempStore();

  await store.createRelease({ platform: 'android', versionCode: 1, versionName: '1.0.0', apkBuffer: Buffer.from('v1') });
  await store.createRelease({ platform: 'android', versionCode: 3, versionName: '1.2.0', apkBuffer: Buffer.from('v3') });
  await store.createRelease({ platform: 'android', versionCode: 2, versionName: '1.1.0', apkBuffer: Buffer.from('v2') });

  const latest = await store.getLatestRelease({ platform: 'android' });
  assert.equal(latest.version_code, 3);
  assert.equal(latest.version_name, '1.2.0');

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore getLatestRelease returns null when no releases exist for platform', async () => {
  const { store, storageDir } = await createTempStore();

  const latest = await store.getLatestRelease({ platform: 'ios' });
  assert.equal(latest, null);

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore listReleases returns all releases sorted by version_code desc', async () => {
  const { store, storageDir } = await createTempStore();

  await store.createRelease({ platform: 'android', versionCode: 2, versionName: '1.1.0', apkBuffer: Buffer.from('v2') });
  await store.createRelease({ platform: 'android', versionCode: 1, versionName: '1.0.0', apkBuffer: Buffer.from('v1') });
  await store.createRelease({ platform: 'android', versionCode: 3, versionName: '1.2.0', apkBuffer: Buffer.from('v3') });

  const releases = await store.listReleases();
  assert.equal(releases.length, 3);
  assert.deepEqual(
    releases.map((r) => r.version_code),
    [3, 2, 1]
  );

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore prunes oldest release when exceeding max per platform', async () => {
  const { store, storageDir } = await createTempStore({ maxVersionsPerPlatform: 3 });

  const r1 = await store.createRelease({
    platform: 'android',
    versionCode: 1,
    versionName: '1.0.0',
    apkBuffer: Buffer.from('v1')
  });
  await store.createRelease({ platform: 'android', versionCode: 2, versionName: '1.1.0', apkBuffer: Buffer.from('v2') });
  await store.createRelease({ platform: 'android', versionCode: 3, versionName: '1.2.0', apkBuffer: Buffer.from('v3') });

  // 4th release should prune the oldest (version_code=1)
  await store.createRelease({ platform: 'android', versionCode: 4, versionName: '1.3.0', apkBuffer: Buffer.from('v4') });

  const releases = await store.listReleases();
  assert.equal(releases.length, 3);
  assert.deepEqual(
    releases.map((r) => r.version_code),
    [4, 3, 2]
  );

  // Verify v1 APK file was deleted
  const v1Stat = await stat(r1.apk_path).catch(() => null);
  assert.equal(v1Stat, null);

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore upload within cap does not prune', async () => {
  const { store, storageDir } = await createTempStore({ maxVersionsPerPlatform: 5 });

  await store.createRelease({ platform: 'android', versionCode: 1, versionName: '1.0.0', apkBuffer: Buffer.from('v1') });
  await store.createRelease({ platform: 'android', versionCode: 2, versionName: '1.1.0', apkBuffer: Buffer.from('v2') });
  await store.createRelease({ platform: 'android', versionCode: 3, versionName: '1.2.0', apkBuffer: Buffer.from('v3') });

  const releases = await store.listReleases();
  assert.equal(releases.length, 3);

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore deleteRelease removes files and returns true', async () => {
  const { store, storageDir } = await createTempStore();

  const release = await store.createRelease({
    platform: 'android',
    versionCode: 1,
    versionName: '1.0.0',
    apkBuffer: Buffer.from('to-delete')
  });

  const deleted = await store.deleteRelease({ id: release.id });
  assert.equal(deleted, true);

  // Verify file was deleted
  const fileStat = await stat(release.apk_path).catch(() => null);
  assert.equal(fileStat, null);

  // Verify it no longer appears in list
  const releases = await store.listReleases();
  assert.equal(releases.length, 0);

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore deleteRelease returns false for unknown id', async () => {
  const { store, storageDir } = await createTempStore();

  const deleted = await store.deleteRelease({ id: 'nonexistent-id' });
  assert.equal(deleted, false);

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore getReleaseById returns null for unknown id', async () => {
  const { store, storageDir } = await createTempStore();

  const release = await store.getReleaseById({ id: 'nonexistent-id' });
  assert.equal(release, null);

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore getReleaseById returns the release for a valid id', async () => {
  const { store, storageDir } = await createTempStore();

  const created = await store.createRelease({
    platform: 'android',
    versionCode: 5,
    versionName: '2.0.0',
    apkBuffer: Buffer.from('release-data')
  });

  const found = await store.getReleaseById({ id: created.id });
  assert.equal(found.id, created.id);
  assert.equal(found.version_code, 5);
  assert.equal(found.version_name, '2.0.0');

  await rm(storageDir, { recursive: true, force: true });
});

test('ReleaseStore prune does not affect other platforms', async () => {
  const { store, storageDir } = await createTempStore({ maxVersionsPerPlatform: 2 });

  await store.createRelease({ platform: 'android', versionCode: 1, versionName: '1.0.0', apkBuffer: Buffer.from('a1') });
  await store.createRelease({ platform: 'android', versionCode: 2, versionName: '1.1.0', apkBuffer: Buffer.from('a2') });
  await store.createRelease({ platform: 'ios', versionCode: 1, versionName: '1.0.0', apkBuffer: Buffer.from('i1') });

  // 3rd android release should prune oldest android but not ios
  await store.createRelease({ platform: 'android', versionCode: 3, versionName: '1.2.0', apkBuffer: Buffer.from('a3') });

  const releases = await store.listReleases();
  const androidReleases = releases.filter((r) => r.platform === 'android');
  const iosReleases = releases.filter((r) => r.platform === 'ios');

  assert.equal(androidReleases.length, 2);
  assert.equal(iosReleases.length, 1);
  assert.deepEqual(
    androidReleases.map((r) => r.version_code),
    [3, 2]
  );

  await rm(storageDir, { recursive: true, force: true });
});
