import { stat } from 'node:fs/promises';
import express from 'express';
import { openReleaseReadStream } from '../release_store.js';
import { asyncHandler, hasAdminAccess } from './helpers.js';

export function createReleasesRouter({ releaseStore, config }) {
  const router = express.Router();

  // ─── Admin endpoints ────────────────────────────────────────────────────────

  router.post(
    '/admin/releases',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }

      const platform = request.get('x-expat8-release-platform');
      const versionCodeRaw = request.get('x-expat8-release-version-code');
      const versionName = request.get('x-expat8-release-version-name');

      if (!platform) {
        return response.status(400).json({ error: 'bad_request', message: 'Missing x-expat8-release-platform header' });
      }
      if (!versionCodeRaw) {
        return response
          .status(400)
          .json({ error: 'bad_request', message: 'Missing x-expat8-release-version-code header' });
      }
      if (!versionName) {
        return response
          .status(400)
          .json({ error: 'bad_request', message: 'Missing x-expat8-release-version-name header' });
      }

      const versionCode = Number.parseInt(versionCodeRaw, 10);
      if (!Number.isInteger(versionCode) || versionCode < 1) {
        return response.status(400).json({ error: 'bad_request', message: 'version_code must be a positive integer' });
      }

      const apkBuffer = request.rawBody;
      if (!apkBuffer || apkBuffer.length === 0) {
        return response.status(400).json({ error: 'bad_request', message: 'Missing file attachment (request body)' });
      }

      const release = await releaseStore.createRelease({
        platform,
        versionCode,
        versionName,
        apkBuffer
      });

      return response.status(201).json({
        id: release.id,
        platform: release.platform,
        version_code: release.version_code,
        version_name: release.version_name,
        file_size_bytes: release.file_size_bytes,
        sha256: release.sha256,
        created_at: release.created_at
      });
    })
  );

  router.get(
    '/admin/releases',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }

      const releases = await releaseStore.listReleases();
      return response.json({
        items: releases.map((r) => ({
          id: r.id,
          platform: r.platform,
          version_code: r.version_code,
          version_name: r.version_name,
          file_size_bytes: r.file_size_bytes,
          sha256: r.sha256,
          created_at: r.created_at
        }))
      });
    })
  );

  router.delete(
    '/admin/releases/:id',
    asyncHandler(async (request, response) => {
      if (!hasAdminAccess({ request, config })) {
        return response.status(403).json({ error: 'forbidden' });
      }

      const deleted = await releaseStore.deleteRelease({ id: request.params.id });
      if (!deleted) {
        return response.status(404).json({ error: 'not_found' });
      }
      return response.status(204).end();
    })
  );

  // ─── Public endpoints (app-credential auth only, no user session) ───────────

  router.get(
    '/releases/latest',
    asyncHandler(async (request, response) => {
      const platform = request.query.platform;
      if (!platform) {
        return response.status(400).json({ error: 'bad_request', message: 'Missing platform query parameter' });
      }

      const release = await releaseStore.getLatestRelease({ platform });
      if (!release) {
        return response.json({ release: null });
      }

      return response.json({
        release: {
          id: release.id,
          platform: release.platform,
          version_code: release.version_code,
          version_name: release.version_name,
          file_size_bytes: release.file_size_bytes,
          sha256: release.sha256,
          created_at: release.created_at
        }
      });
    })
  );

  router.get(
    '/releases/:id/download',
    asyncHandler(async (request, response) => {
      const release = await releaseStore.getReleaseById({ id: request.params.id });
      if (!release) {
        return response.status(404).json({ error: 'not_found' });
      }

      // Verify file still exists on disk
      const fileStat = await stat(release.apk_path).catch(() => null);
      if (!fileStat) {
        return response.status(404).json({ error: 'not_found', message: 'Release file missing from storage' });
      }

      response.setHeader('Content-Type', 'application/vnd.android.package-archive');
      response.setHeader('Content-Length', fileStat.size);
      response.setHeader(
        'Content-Disposition',
        `attachment; filename="release-${release.version_name}.apk"`
      );

      const stream = openReleaseReadStream(release);
      stream.pipe(response);
    })
  );

  return router;
}
