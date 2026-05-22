import crypto from 'node:crypto';
import { createReadStream } from 'node:fs';
import { mkdir, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';

const DEFAULT_MAX_VERSIONS_PER_PLATFORM = 5;

export class ReleaseStore {
  constructor({
    storageDir,
    maxVersionsPerPlatform = DEFAULT_MAX_VERSIONS_PER_PLATFORM,
    logger = console
  } = {}) {
    if (!storageDir) {
      throw new Error('storageDir is required');
    }
    this.storageDir = path.resolve(storageDir);
    this.maxVersionsPerPlatform = maxVersionsPerPlatform;
    this.logger = logger;
  }

  async createRelease({ platform, versionCode, versionName, apkBuffer }) {
    if (!platform || typeof platform !== 'string') {
      throw new Error('platform is required');
    }
    if (!Number.isInteger(versionCode) || versionCode < 1) {
      throw new Error('versionCode must be a positive integer');
    }
    if (!versionName || typeof versionName !== 'string') {
      throw new Error('versionName is required');
    }
    if (!Buffer.isBuffer(apkBuffer) || apkBuffer.length === 0) {
      throw new Error('apkBuffer must be a non-empty Buffer');
    }

    const id = crypto.randomUUID();
    const sha256 = crypto.createHash('sha256').update(apkBuffer).digest('hex');
    const createdAt = new Date().toISOString();
    const record = {
      id,
      platform,
      version_code: versionCode,
      version_name: versionName,
      file_size_bytes: apkBuffer.length,
      sha256,
      created_at: createdAt
    };

    await this.#ensureStorageDir();

    const apkPath = this.#apkPath(id);
    const metaPath = this.#metaPath(id);

    try {
      await writeFile(apkPath, apkBuffer);
      await writeFile(metaPath, JSON.stringify(record, null, 2), 'utf8');
    } catch (error) {
      await Promise.allSettled([rm(apkPath, { force: true }), rm(metaPath, { force: true })]);
      throw error;
    }

    await this.#pruneForPlatform(platform);

    return this.#toRelease(record, apkPath);
  }

  async getLatestRelease({ platform } = {}) {
    if (!platform) {
      throw new Error('platform is required');
    }
    const releases = await this.#loadReleases();
    const platformReleases = releases.filter((r) => r.platform === platform);
    if (platformReleases.length === 0) {
      return null;
    }
    return platformReleases.sort((a, b) => b.version_code - a.version_code)[0];
  }

  async listReleases() {
    const releases = await this.#loadReleases();
    return releases.sort((a, b) => b.version_code - a.version_code || b.created_at.localeCompare(a.created_at));
  }

  async getReleaseById({ id } = {}) {
    const releases = await this.#loadReleases();
    return releases.find((r) => r.id === id) ?? null;
  }

  async deleteRelease({ id } = {}) {
    const releases = await this.#loadReleases();
    const release = releases.find((r) => r.id === id);
    if (!release) {
      return false;
    }
    await this.#deleteReleaseFiles(id);
    return true;
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  async #ensureStorageDir() {
    await mkdir(this.storageDir, { recursive: true });
  }

  #apkPath(id) {
    return path.join(this.storageDir, `${id}.apk`);
  }

  #metaPath(id) {
    return path.join(this.storageDir, `${id}.json`);
  }

  async #deleteReleaseFiles(id) {
    await Promise.allSettled([rm(this.#apkPath(id), { force: true }), rm(this.#metaPath(id), { force: true })]);
  }

  async #pruneForPlatform(platform) {
    const releases = await this.#loadReleases();
    const platformReleases = releases
      .filter((r) => r.platform === platform)
      .sort((a, b) => b.version_code - a.version_code || b.created_at.localeCompare(a.created_at));

    if (platformReleases.length <= this.maxVersionsPerPlatform) {
      return;
    }

    const toDelete = platformReleases.slice(this.maxVersionsPerPlatform);
    for (const release of toDelete) {
      this.logger.info?.('release_store_pruning', { id: release.id, version_code: release.version_code });
      await this.#deleteReleaseFiles(release.id);
    }
  }

  async #loadReleases() {
    await this.#ensureStorageDir();

    const entries = await readdir(this.storageDir, { withFileTypes: true });
    const metaEntries = entries.filter((entry) => entry.isFile() && entry.name.endsWith('.json'));
    const releases = [];

    for (const entry of metaEntries) {
      const metaPath = path.join(this.storageDir, entry.name);
      const id = entry.name.replace(/\.json$/, '');
      const apkPath = this.#apkPath(id);

      const rawMeta = await readFile(metaPath, 'utf8').catch(() => null);
      if (!rawMeta) {
        await rm(apkPath, { force: true });
        continue;
      }

      let meta;
      try {
        meta = JSON.parse(rawMeta);
      } catch (_error) {
        this.logger.warn?.('release_store_metadata_invalid', { path: metaPath });
        await Promise.allSettled([rm(apkPath, { force: true }), rm(metaPath, { force: true })]);
        continue;
      }

      const apkStat = await stat(apkPath).catch(() => null);
      if (!apkStat) {
        this.logger.warn?.('release_store_apk_missing', { path: apkPath });
        await rm(metaPath, { force: true });
        continue;
      }

      releases.push(this.#toRelease(meta, apkPath));
    }

    return releases;
  }

  #toRelease(meta, apkPath) {
    return {
      id: meta.id,
      platform: meta.platform,
      version_code: meta.version_code,
      version_name: meta.version_name,
      file_size_bytes: meta.file_size_bytes,
      sha256: meta.sha256,
      created_at: meta.created_at,
      apk_path: apkPath
    };
  }
}

export function openReleaseReadStream(release) {
  return createReadStream(release.apk_path);
}
