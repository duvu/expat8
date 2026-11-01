import { formatFullTimestamp, formatRelative, formatShortDate, formatShortDateTime } from '@/lib/datetime';

type Props = {
  value: string | Date | null | undefined;
  /** Date only ("Oct 27"), no time of day. */
  dateOnly?: boolean;
  /** Prefer "2h ago" when the value is recent (falls back to the short date). */
  relative?: boolean;
};

/** One-line compact date with the full UTC timestamp in the tooltip. */
export default function DateTime({ value, dateOnly, relative }: Props) {
  const text = (relative ? formatRelative(value) : null)
    ?? (dateOnly ? formatShortDate(value) : formatShortDateTime(value));
  if (text === '—') return <span className="muted">—</span>;
  const iso = value instanceof Date ? value.toISOString() : String(value);
  return <time className="nowrap" dateTime={iso} title={formatFullTimestamp(value)}>{text}</time>;
}
