/** Uppercase language code ("EN"); the full value stays available to assistive tech. */
export default function LanguageChip({ code }: { code: string | null | undefined }) {
  if (!code) return <span className="muted">—</span>;
  return <span className="lang-chip" title={code}>{code.toUpperCase()}</span>;
}
