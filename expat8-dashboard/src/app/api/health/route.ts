export const dynamic = 'force-dynamic';

/** Liveness probe for the container (does not touch the backend or database). */
export function GET() {
  return Response.json({ status: 'ok' });
}
