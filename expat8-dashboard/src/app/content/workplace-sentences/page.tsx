import { listWorkplaceSentences } from '@/lib/analytics';
import PageShell from '@/components/PageShell';

export const dynamic = 'force-dynamic';

export default async function WorkplaceSentencesPage({
  searchParams,
}: {
  searchParams: Promise<{ topic?: string; language?: string; range?: string }>;
}) {
  const params = await searchParams;
  const topic = params.topic ?? '';
  const language = params.language ?? '';

  const sentences = await listWorkplaceSentences({ topic: topic || undefined, language: language || undefined });

  return (
    <PageShell title="Workplace Sentences">
      <section className="table-panel">
        <form className="toolbar">
          <label>
            Topic
            <input type="text" name="topic" defaultValue={topic} placeholder="e.g. meetings" />
          </label>
          <label>
            Language
            <input type="text" name="language" defaultValue={language} placeholder="e.g. en" />
          </label>
          <button type="submit">Filter</button>
        </form>
      </section>

      <section className="table-panel">
        <table>
          <thead>
            <tr>
              <th>Sentence</th>
              <th>Topic</th>
              <th>Language</th>
              <th>Article</th>
              <th>Created At</th>
            </tr>
          </thead>
          <tbody>
            {sentences.length === 0 ? (
              <tr>
                <td colSpan={5}><div className="empty-state">No workplace sentences found.</div></td>
              </tr>
            ) : sentences.map((s) => (
              <tr key={s.id}>
                <td data-label="Sentence">
                  {s.sentence.length > 80 ? `${s.sentence.slice(0, 80)}…` : s.sentence}
                </td>
                <td data-label="Topic">{s.topic ?? '—'}</td>
                <td data-label="Language">{s.language}</td>
                <td data-label="Article">{s.article_id ?? <span className="muted">—</span>}</td>
                <td data-label="Created At">{new Date(s.created_at).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </PageShell>
  );
}
