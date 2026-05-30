import { getAdminConfig } from '@/lib/config';

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const { backendBaseUrl } = getAdminConfig();
  const url = new URL(`/v1/exam/certificate/${id}`, backendBaseUrl);

  const upstream = await fetch(url.toString());
  const data = await upstream.json();

  return Response.json(data, { status: upstream.status });
}
