import { backendFetch, readErrorMessage } from './backend';
import { getAdminConfig } from './config';

export type SpeakingLoopHealth = {
  week_start: string;
  loop_completion_count: number;
  drill_session_count: number;
  latest_approved_prompt_at: string | null;
  latest_published_passage_at: string | null;
};

export type ContentPipelineSection = {
  pending_count: number;
  failed_count: number;
  last_processed_at: string | null;
};

export type ContentPipelineHealth = {
  articles: ContentPipelineSection;
  memorization: ContentPipelineSection;
  shadowing: ContentPipelineSection;
};

export type GamesSummary = {
  days: number;
  total_rounds: number;
  players: number;
  mean_accuracy: number;
  words_reviewed_via_games: number;
  rounds_by_mode: Record<string, number>;
  accuracy_buckets: {
    under_50: number;
    from_50_to_70: number;
    from_70_to_85: number;
    from_85: number;
  };
  rounds_per_day: { day: string; rounds: number; players: number }[];
};

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
};

export type HealthProbe = {
  ok: boolean;
  detail: string;
};

/** Result of a backend read: `data` is null when missing (404) or on error. */
export type LoadResult<T> = { data: T | null; error: string | null };

/** Backend `GET /v1/admin/log-archives` caps `limit` at 200. */
export const LOG_ARCHIVE_LIMIT_MAX = 200;

export async function loadOpsOverview() {
  const checkedAt = new Date().toISOString();
  const [live, ready, archives, loopHealth, pipelineHealth, games] = await Promise.all([
    probeHealth('/health'),
    probeHealth('/health/ready'),
    loadLogArchives(),
    loadSpeakingLoopHealth(),
    loadContentPipelineHealth(),
    loadGamesSummary(),
  ]);
  return { checkedAt, live, ready, archives, loopHealth, pipelineHealth, games };
}

export async function loadLogArchives(): Promise<{ items: LogArchiveRecord[]; error: string | null }> {
  const { data, error } = await loadJson<{ items?: LogArchiveRecord[] }>(
    `/v1/admin/log-archives?limit=${LOG_ARCHIVE_LIMIT_MAX}`,
    'Unable to load log archives'
  );
  return { items: data?.items ?? [], error };
}

export function loadSpeakingLoopHealth() {
  return loadJson<SpeakingLoopHealth>('/v1/admin/speaking/weekly-health', 'Unable to load loop health');
}

export function loadContentPipelineHealth() {
  return loadJson<ContentPipelineHealth>('/v1/admin/content-pipeline/health', 'Unable to load content pipeline health');
}

export function loadGamesSummary(days = 30) {
  return loadJson<GamesSummary>(`/v1/admin/games/summary?days=${days}`, 'Unable to load game analytics');
}

export function loadLogArchive(id: string) {
  return loadJson<LogArchiveRecord>(`/v1/admin/log-archives/${encodeURIComponent(id)}`, 'Unable to load log archive');
}

export function loadLogArchiveContent(id: string) {
  return load(
    `/v1/admin/log-archives/${encodeURIComponent(id)}/content`,
    'Unable to load log archive content',
    (response) => response.text()
  );
}

export async function deleteLogArchive(id: string): Promise<{ error: string | null }> {
  try {
    const response = await backendFetch(`/v1/admin/log-archives/${encodeURIComponent(id)}`, { method: 'DELETE' });
    return { error: response.ok ? null : await readErrorMessage(response, 'Unable to delete log archive') };
  } catch (error) {
    return { error: errorMessage(error, 'Unable to delete log archive') };
  }
}

/** Streams an archive download through the dashboard (the backend URL needs signed headers). */
export function fetchLogArchiveDownload(id: string) {
  return backendFetch(`/v1/admin/log-archives/${encodeURIComponent(id)}/download`);
}

function loadJson<T>(path: string, fallback: string): Promise<LoadResult<T>> {
  return load(path, fallback, (response) => response.json() as Promise<T>);
}

async function load<T>(path: string, fallback: string, parse: (response: Response) => Promise<T>): Promise<LoadResult<T>> {
  try {
    const response = await backendFetch(path);
    if (response.status === 404) {
      return { data: null, error: null };
    }
    if (!response.ok) {
      return { data: null, error: await readErrorMessage(response, fallback) };
    }
    return { data: await parse(response), error: null };
  } catch (error) {
    return { data: null, error: errorMessage(error, fallback) };
  }
}

async function probeHealth(path: '/health' | '/health/ready'): Promise<HealthProbe> {
  try {
    const response = await fetch(new URL(path, getAdminConfig().backendBaseUrl), { cache: 'no-store' });
    const payload = await response.json().catch(() => ({})) as { db?: string; error?: string };
    if (response.ok) {
      return { ok: true, detail: path === '/health' ? 'Reachable' : payload.db ?? 'ok' };
    }
    return { ok: false, detail: payload.db ?? payload.error ?? `HTTP ${response.status}` };
  } catch (error) {
    return { ok: false, detail: errorMessage(error, 'Request failed') };
  }
}

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error ? error.message : fallback;
}
