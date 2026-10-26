import { getAdminConfig } from '@/lib/config';

export const dynamic = 'force-dynamic';

/** Proxies the backend's public certificate endpoint (no app-credential signing needed). */
export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const url = new URL(`/v1/exam/certificate/${encodeURIComponent(id)}`, getAdminConfig().backendBaseUrl);
  try {
    const upstream = await fetch(url, { cache: 'no-store' });
    const data = await upstream.json().catch(() => ({ error: 'invalid_upstream_response' }));
    return Response.json(data, { status: upstream.status });
  } catch {
    return Response.json({ error: 'backend_unreachable' }, { status: 502 });
  }
}
