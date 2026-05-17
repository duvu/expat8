import crypto from 'node:crypto';
import { createReadStream } from 'node:fs';
import {
  mkdir,
  readdir,
  readFile,
  rm,
  stat,
  writeFile
} from 'node:fs/promises';
import path from 'node:path';

const DEFAULT_RETENTION_DAYS = 3;
const DEFAULT_MAX_TOTAL_BYTES = 100 * 1024 * 1024;
const DEFAULT_CONTENT_TYPE = 'text/plain; charset=utf-8';
const DAY_MS = 24 * 60 * 60 * 1000;

export class FileLogArchiveStore {
  constructor({
    rootDir,
    retentionDays = DEFAULT_RETENTION_DAYS,
    maxTotalBytes = DEFAULT_MAX_TOTAL_BYTES,
    logger = console
  } = {}) {
    if (!rootDir) {
      throw new Error('rootDir is required');
    }
    this.rootDir = path.resolve(rootDir);
    this.retentionDays = retentionDays;
    this.maxTotalBytes = maxTotalBytes;
    this.logger = logger;
  }

  async saveArchive({
    appId,
    userId = null,
    deviceId = null,
    sourceLabel = 'mobile',
    originalFileName = null,
    contentType = DEFAULT_CONTENT_TYPE,
    body,
    uploadedAt = new Date(),
    now = new Date()
  }) {
    if (!appId) {
      throw new Error('appId is required');
    }

    const archiveId = crypto.randomUUID();
    const content = Buffer.isBuffer(body) ? body : Buffer.from(String(body ?? ''), 'utf8');
    const createdAt = uploadedAt instanceof Date ? uploadedAt : new Date(uploadedAt);
    const record = {
      id: archiveId,
      app_id: appId,
      user_id: userId,
      device_id: deviceId,
      source_label: sourceLabel,
      original_file_name: originalFileName,
      content_type: contentType || DEFAULT_CONTENT_TYPE,
      uploaded_at: createdAt.toISOString(),
      size_bytes: content.length
    };

    await this.#ensureRootDir();

    const contentPath = this.#contentPath(archiveId);
    const metaPath = this.#metaPath(archiveId);

    try {
      await writeFile(contentPath, content);
      await writeFile(metaPath, JSON.stringify(record, null, 2), 'utf8');
    } catch (error) {
      await Promise.allSettled([
        rm(contentPath, { force: true }),
        rm(metaPath, { force: true })
      ]);
      throw error;
    }

    await this.cleanupRetention({ now });
    return this.#formatArchive({
      id: archiveId,
      appId,
      userId,
      deviceId,
      sourceLabel,
      originalFileName,
      contentType: contentType || DEFAULT_CONTENT_TYPE,
      sizeBytes: content.length,
      contentPath,
      metaPath,
      uploadedAtMs: createdAt.getTime(),
      now
    });
  }

  async listArchives({ limit = 100, now = new Date() } = {}) {
    await this.cleanupRetention({ now });
    const archives = await this.#loadArchives({ now });
    return archives
      .sort((left, right) => right.uploadedAtMs - left.uploadedAtMs || right.id.localeCompare(left.id))
      .slice(0, Math.max(0, limit));
  }

  async getArchiveById({ id, now = new Date() } = {}) {
    await this.cleanupRetention({ now });
    const archives = await this.#loadArchives({ now });
    return archives.find((archive) => archive.id === id) ?? null;
  }

  async cleanupRetention({ now = new Date() } = {}) {
    const archives = await this.#loadArchives({ now });
    const nowMs = now.getTime();
    const retentionCutoffMs = nowMs - (this.retentionDays * DAY_MS);
    const expiredArchives = archives.filter((archive) => archive.uploadedAtMs < retentionCutoffMs);

    for (const archive of expiredArchives) {
      await this.#deleteArchive(archive);
    }

    let retainedArchives = archives.filter((archive) => archive.uploadedAtMs >= retentionCutoffMs);
    let retainedBytes = retainedArchives.reduce((total, archive) => total + archive.sizeBytes, 0);
    const oldestFirst = [...retainedArchives].sort((left, right) => left.uploadedAtMs - right.uploadedAtMs || left.id.localeCompare(right.id));

    for (const archive of oldestFirst) {
      if (retainedBytes <= this.maxTotalBytes) {
        break;
      }
      await this.#deleteArchive(archive);
      retainedBytes -= archive.sizeBytes;
      retainedArchives = retainedArchives.filter((candidate) => candidate.id !== archive.id);
    }

    return retainedArchives;
  }

  async #ensureRootDir() {
    await mkdir(this.rootDir, { recursive: true });
  }

  #contentPath(id) {
    return path.join(this.rootDir, `${id}.log`);
  }

  #metaPath(id) {
    return path.join(this.rootDir, `${id}.json`);
  }

  async #loadArchives({ now = new Date() } = {}) {
    await this.#ensureRootDir();

    const entries = await readdir(this.rootDir, { withFileTypes: true });
    const metaEntries = entries.filter((entry) => entry.isFile() && entry.name.endsWith('.json'));
    const archives = [];

    for (const entry of metaEntries) {
      const metaPath = path.join(this.rootDir, entry.name);
      const archiveId = entry.name.replace(/\.json$/, '');
      const contentPath = this.#contentPath(archiveId);
      const rawMeta = await readFile(metaPath, 'utf8').catch(() => null);
      if (!rawMeta) {
        await rm(contentPath, { force: true });
        await rm(metaPath, { force: true });
        continue;
      }

      let meta;
      try {
        meta = JSON.parse(rawMeta);
      } catch (_error) {
        this.logger.warn?.('log_archive_metadata_invalid', { path: metaPath });
        await Promise.allSettled([
          rm(contentPath, { force: true }),
          rm(metaPath, { force: true })
        ]);
        continue;
      }

      const contentStat = await stat(contentPath).catch(() => null);
      if (!contentStat) {
        this.logger.warn?.('log_archive_content_missing', { path: contentPath });
        await rm(metaPath, { force: true });
        continue;
      }

      const uploadedAtMs = Date.parse(meta.uploaded_at ?? meta.uploadedAt ?? meta.created_at ?? meta.createdAt);
      if (Number.isNaN(uploadedAtMs)) {
        this.logger.warn?.('log_archive_timestamp_invalid', { path: metaPath });
        await this.#deleteArchive({ contentPath, metaPath });
        continue;
      }

      archives.push(this.#formatArchive({
        id: archiveId,
        appId: meta.app_id ?? meta.appId ?? null,
        userId: meta.user_id ?? meta.userId ?? null,
        deviceId: meta.device_id ?? meta.deviceId ?? null,
        sourceLabel: meta.source_label ?? meta.sourceLabel ?? 'mobile',
        originalFileName: meta.original_file_name ?? meta.originalFileName ?? null,
        contentType: meta.content_type ?? meta.contentType ?? DEFAULT_CONTENT_TYPE,
        uploadedAtMs,
        sizeBytes: contentStat.size,
        contentPath,
        metaPath,
        now
      }));
    }

    return archives;
  }

  async #deleteArchive(archive) {
    await Promise.allSettled([
      rm(archive.contentPath, { force: true }),
      rm(archive.metaPath, { force: true })
    ]);
  }

  #formatArchive({
    id,
    appId,
    userId,
    deviceId,
    sourceLabel,
    originalFileName,
    contentType,
    uploadedAtMs,
    sizeBytes,
    contentPath,
    metaPath,
    now
  }) {
    const retentionExpiresAtMs = uploadedAtMs + (this.retentionDays * DAY_MS);
    return {
      id,
      appId,
      userId,
      deviceId,
      sourceLabel,
      originalFileName,
      contentType,
      uploadedAt: new Date(uploadedAtMs).toISOString(),
      uploadedAtMs,
      sizeBytes,
      retentionExpiresAt: new Date(retentionExpiresAtMs).toISOString(),
      retentionState: retentionExpiresAtMs <= now.getTime() ? 'expired' : 'active',
      contentPath,
      metaPath,
      contentUrl: `/v1/admin/log-archives/${id}/content`,
      downloadUrl: `/v1/admin/log-archives/${id}/download`
    };
  }
}

export function openArchiveReadStream(archive) {
  return createReadStream(archive.contentPath);
}
