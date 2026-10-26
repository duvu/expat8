import { readErrorMessage } from '@/lib/backend';
import { fetchLogArchiveDownload } from '@/lib/ops-data';

export const dynamic = 'force-dynamic';

/**
 * Proxies the archive download: the backend endpoint needs signed app-credential
 * and admin-token headers, which a browser link cannot send.
 */
export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  let upstream: Response;
  try {
    upstream = await fetchLogArchiveDownload(id);
  } catch (error) {
    console.error('[ops] log archive download failed:', error);
    return Response.json({ error: 'backend_unreachable' }, { status: 502 });
  }
  if (!upstream.ok || !upstream.body) {
    const message = await readErrorMessage(upstream, 'Unable to download log archive');
    return Response.json({ error: message }, { status: upstream.status === 404 ? 404 : 502 });
  }

  const headers = new Headers({ 'cache-control': 'no-store' });
  for (const name of ['content-type', 'content-disposition', 'content-length']) {
    const value = upstream.headers.get(name);
    if (value) headers.set(name, value);
  }
  return new Response(upstream.body, { status: 200, headers });
}
