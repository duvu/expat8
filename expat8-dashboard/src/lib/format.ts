/** Display helpers shared by server-rendered pages. */

const EMPTY = '—';

export function formatDate(value: string | null | undefined): string {
  if (!value) return EMPTY;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? EMPTY : date.toLocaleDateString();
}

export function formatSeconds(value: number | null | undefined): string {
  return value == null ? EMPTY : `${value.toFixed(1)}s`;
}

export function truncate(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

export { formatBytes, formatDateTime } from './ops';
