import crypto from 'node:crypto';
import { createReadStream } from 'node:fs';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';

const DEFAULT_MAX_VERSIONS_PER_PLATFORM = 5;

export class PostgresReleaseStore {
  constructor({
    pool,
    storageDir,
    maxVersionsPerPlatform = DEFAULT_MAX_VERSIONS_PER_PLATFORM,
    logger = console
  } = {}) {
    if (!pool) {
      throw new Error('pool is required');
    }
    if (!storageDir) {
      throw new Error('storageDir is required');
    }
    this.pool = pool;
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
    const fileSizeBytes = apkBuffer.length;

    await this.#ensureStorageDir();
    const apkPath = this.#apkPath(id);

    // Write APK file first
    await writeFile(apkPath, apkBuffer);

    try {
      await this.pool.query(
        `INSERT INTO release_versions (id, platform, version_code, version_name, file_path, file_size_bytes, sha256, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [id, platform, versionCode, versionName, apkPath, fileSizeBytes, sha256, createdAt]
      );
    } catch (error) {
      await rm(apkPath, { force: true });
      throw error;
    }

    await this.#pruneForPlatform(platform);

    return {
      id,
      platform,
      version_code: versionCode,
      version_name: versionName,
      file_size_bytes: fileSizeBytes,
      sha256,
      created_at: createdAt,
      apk_path: apkPath
    };
  }

  async getLatestRelease({ platform } = {}) {
    if (!platform) {
      throw new Error('platform is required');
    }
    const { rows } = await this.pool.query(
      `SELECT id, platform, version_code, version_name, file_path, file_size_bytes, sha256, created_at
       FROM release_versions
       WHERE platform = $1
       ORDER BY version_code DESC
       LIMIT 1`,
      [platform]
    );
    if (rows.length === 0) {
      return null;
    }
    return this.#rowToRelease(rows[0]);
  }

  async listReleases() {
    const { rows } = await this.pool.query(
      `SELECT id, platform, version_code, version_name, file_path, file_size_bytes, sha256, created_at
       FROM release_versions
       ORDER BY version_code DESC, created_at DESC`
    );
    return rows.map((row) => this.#rowToRelease(row));
  }

  async getReleaseById({ id } = {}) {
    const { rows } = await this.pool.query(
      `SELECT id, platform, version_code, version_name, file_path, file_size_bytes, sha256, created_at
       FROM release_versions
       WHERE id = $1`,
      [id]
    );
    if (rows.length === 0) {
      return null;
    }
    return this.#rowToRelease(rows[0]);
  }

  async deleteRelease({ id } = {}) {
    const { rows } = await this.pool.query(
      `DELETE FROM release_versions WHERE id = $1 RETURNING file_path`,
      [id]
    );
    if (rows.length === 0) {
      return false;
    }
    await rm(rows[0].file_path, { force: true });
    return true;
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  async #ensureStorageDir() {
    await mkdir(this.storageDir, { recursive: true });
  }

  #apkPath(id) {
    return path.join(this.storageDir, `${id}.apk`);
  }

  async #pruneForPlatform(platform) {
    const { rows } = await this.pool.query(
      `SELECT id, file_path FROM release_versions
       WHERE platform = $1
       ORDER BY version_code DESC, created_at DESC
       OFFSET $2`,
      [platform, this.maxVersionsPerPlatform]
    );

    for (const row of rows) {
      this.logger.info?.('release_store_pruning', { id: row.id });
      await rm(row.file_path, { force: true });
      await this.pool.query(`DELETE FROM release_versions WHERE id = $1`, [row.id]);
    }
  }

  #rowToRelease(row) {
    return {
      id: row.id,
      platform: row.platform,
      version_code: row.version_code,
      version_name: row.version_name,
      file_size_bytes: row.file_size_bytes,
      sha256: row.sha256,
      created_at: row.created_at,
      apk_path: row.file_path
    };
  }
}

export function openReleaseReadStream(release) {
  return createReadStream(release.apk_path);
}
