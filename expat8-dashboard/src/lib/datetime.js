/**
 * Compact, locale-stable display helpers (pure; unit-tested in test/display.test.js).
 * Everything is rendered in UTC so server output is deterministic; the full
 * timestamp is always available in a tooltip via `formatFullTimestamp`.
 */

const EMPTY = '—';
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const dayFormat = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' });
const dayYearFormat = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
const timeFormat = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', timeZone: 'UTC' });
const clockFormat = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'UTC' });
const compactFormat = new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 });

function toDate(value) {
  if (value == null || value === '') return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function sameYear(a, b) {
  return a.getUTCFullYear() === b.getUTCFullYear();
}

/** "Oct 27" (adds the year when it is not the current one). */
export function formatShortDate(value, now = new Date()) {
  const date = toDate(value);
  if (!date) return EMPTY;
  return (sameYear(date, now) ? dayFormat : dayYearFormat).format(date);
}

/** "Oct 27, 8:00 AM" (adds the year when it is not the current one). */
export function formatShortDateTime(value, now = new Date()) {
  const date = toDate(value);
  if (!date) return EMPTY;
  return `${formatShortDate(date, now)}, ${timeFormat.format(date)}`;
}

/** "2026-10-27 08:00:00 UTC", for tooltips. */
export function formatFullTimestamp(value) {
  const date = toDate(value);
  if (!date) return '';
  return `${date.toISOString().slice(0, 19).replace('T', ' ')} UTC`;
}

/** "08:05" clock time in UTC. */
export function formatClock(value) {
  const date = toDate(value);
  return date ? clockFormat.format(date) : EMPTY;
}

/** "just now", "5m ago", "2h ago", "3d ago"; null when older than 30 days or invalid. */
export function formatRelative(value, now = new Date()) {
  const date = toDate(value);
  if (!date) return null;
  const diff = now.getTime() - date.getTime();
  const abs = Math.abs(diff);
  if (abs < MINUTE) return 'just now';
  if (abs >= 30 * DAY) return null;
  const amount = abs < HOUR ? `${Math.floor(abs / MINUTE)}m` : abs < DAY ? `${Math.floor(abs / HOUR)}h` : `${Math.floor(abs / DAY)}d`;
  return diff >= 0 ? `${amount} ago` : `in ${amount}`;
}

/** "2026-10-25" -> "Oct 25"; any other value is returned unchanged. */
export function formatAxisDate(value) {
  const text = String(value);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return text;
  const date = new Date(`${text}T00:00:00Z`);
  return Number.isNaN(date.getTime()) ? text : dayFormat.format(date);
}

/** 1200 -> "1.2K" for axis ticks. */
export function formatCompact(value) {
  const number = Number(value);
  return Number.isFinite(number) ? compactFormat.format(number) : String(value);
}

/** Tooltip/value formatting with thousands separators. */
export function formatNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number.toLocaleString('en-US') : String(value);
}
