import { backendFetch } from './backend';
import { getAdminConfig } from './config';

export type LogArchiveRecord = {
  id: string;
  file_name: string;
  content_type: string;
  size_bytes: number;
  uploaded_at: string;
  source_app_id: string | null;
  source_device_id: string | null;
  source_user_id: string | null;
  source_label: string | null;
  retention_expires_at: string;
  retention_state: 'active' | 'expired';
  content_url: string;
  download_url: string;
};

export type HealthProbe = {
  ok: boolean;
  status: number;
  checkedAt: string;
  label: string;
  detail: string;
};

export type OpsOverview = {
  checkedAt: string;
  live: HealthProbe;
  ready: HealthProbe;
  archives: LogArchiveRecord[];
  archivesError: string | null;
};

export async function loadOpsOverview({ limit = 200 } = {}): Promise<OpsOverview> {
  const checkedAt = new Date().toISOString();
  const [live, ready, archivesResult] = await Promise.all([
    probeHealth('/health', 'Backend live', checkedAt),
    probeHealth('/health/ready', 'Backend ready', checkedAt),
    loadLogArchives({ limit }),
  ]);

  return {
    checkedAt,
    live,
    ready,
    archives: archivesResult.items,
    archivesError: archivesResult.error,
  };
}

export async function loadLogArchives({ limit = 200 } = {}): Promise<{
  items: LogArchiveRecord[];
  error: string | null;
}> {
  try {
    ensureDashboardCredentials();
    const response = await backendFetch(`/v1/admin/log-archives?limit=${limit}`);
    if (!response.ok) {
      return {
        items: [],
        error: await readErrorMessage(response, 'Unable to load log archives'),
      };
    }

    const payload = await response.json() as { items?: LogArchiveRecord[] };
    const config = getAdminConfig();
    return {
      items: (payload.items ?? []).map((archive) => normalizeArchiveUrls(archive, config.backendBaseUrl)),
      error: null,
    };
  } catch (error) {
    return {
      items: [],
      error: error instanceof Error ? error.message : 'Unable to load log archives',
    };
  }
}

export async function loadLogArchive(id: string): Promise<{
  archive: LogArchiveRecord | null;
  error: string | null;
}> {
  try {
    ensureDashboardCredentials();
    const response = await backendFetch(`/v1/admin/log-archives/${id}`);
    if (response.status === 404) {
      return { archive: null, error: null };
    }
    if (!response.ok) {
      return {
        archive: null,
        error: await readErrorMessage(response, 'Unable to load log archive'),
      };
    }

    const config = getAdminConfig();
    return {
      archive: normalizeArchiveUrls(await response.json() as LogArchiveRecord, config.backendBaseUrl),
      error: null,
    };
  } catch (error) {
    return {
      archive: null,
      error: error instanceof Error ? error.message : 'Unable to load log archive',
    };
  }
}

export async function loadLogArchiveContent(id: string): Promise<{
  content: string | null;
  error: string | null;
}> {
  try {
    ensureDashboardCredentials();
    const response = await backendFetch(`/v1/admin/log-archives/${id}/content`);
    if (response.status === 404) {
      return { content: null, error: null };
    }
    if (!response.ok) {
      return {
        content: null,
        error: await readErrorMessage(response, 'Unable to load log archive content'),
      };
    }

    return {
      content: await response.text(),
      error: null,
    };
  } catch (error) {
    return {
      content: null,
      error: error instanceof Error ? error.message : 'Unable to load log archive content',
    };
  }
}

export async function deleteLogArchive(id: string): Promise<{ error: string | null }> {
  try {
    ensureDashboardCredentials();
    const response = await backendFetch(`/v1/admin/log-archives/${id}`, { method: 'DELETE' });
    if (!response.ok) {
      return { error: await readErrorMessage(response, 'Unable to delete log archive') };
    }
    return { error: null };
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Unable to delete log archive' };
  }
}

async function probeHealth(path: string, label: string, checkedAt: string): Promise<HealthProbe> {
  const config = getAdminConfig();
  const url = new URL(path, config.backendBaseUrl);

  try {
    const response = await fetch(url, { cache: 'no-store' });
    const payload = await response.json().catch(() => ({})) as { db?: string; error?: string };
    return {
      ok: response.ok,
      status: response.status,
      checkedAt,
      label,
      detail: response.ok ? (path === '/health' ? 'Reachable' : payload.db ?? 'ok') : payload.db ?? payload.error ?? `HTTP ${response.status}`,
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      checkedAt,
      label,
      detail: error instanceof Error ? error.message : 'Request failed',
    };
  }
}

function ensureDashboardCredentials() {
  const config = getAdminConfig();
  if (!config.appId || !config.appSecret) {
    throw new Error('Missing dashboard backend credentials: APP_CREDENTIAL_APP_ID and APP_CREDENTIAL_SECRET are required');
  }
}

function normalizeArchiveUrls(archive: LogArchiveRecord, backendBaseUrl: string): LogArchiveRecord {
  return {
    ...archive,
    content_url: new URL(archive.content_url, backendBaseUrl).toString(),
    download_url: new URL(archive.download_url, backendBaseUrl).toString(),
  };
}

async function readErrorMessage(response: Response, fallback: string) {
  try {
    const body = await response.json() as { error?: string; message?: string };
    return body.message ?? body.error ?? fallback;
  } catch (_error) {
    return fallback;
  }
}
