import { notFound } from 'next/navigation';
import { revalidatePath } from 'next/cache';

import { backendFetch } from '@/lib/backend';
import { getAdminArticle, listArticleVocabulary } from '@/lib/db';
import { getArticleProcessingJobs, getArticleWorkplaceSentences } from '@/lib/analytics';
import PageShell from '@/components/PageShell';

export const dynamic = 'force-dynamic';

async function publishArticle(formData: FormData) {
  'use server';
  const articleId = String(formData.get('articleId') ?? '');
  await backendFetch(`/v1/admin/articles/${articleId}/publish`, { method: 'POST' });
  revalidatePath(`/articles/${articleId}`);
  revalidatePath('/articles');
}

async function reprocessArticle(formData: FormData) {
  'use server';
  const articleId = String(formData.get('articleId') ?? '');
  await backendFetch(`/v1/admin/articles/${articleId}/reprocess`, { method: 'POST' });
  revalidatePath(`/articles/${articleId}`);
  revalidatePath('/articles');
}

async function patchArticle(formData: FormData) {
  'use server';
  const articleId = String(formData.get('articleId') ?? '');
  const patch: Record<string, string> = {};
  const title = formData.get('title');
  const language = formData.get('language');
  const visibility = formData.get('visibility');
  if (title && typeof title === 'string') patch.title = title;
  if (language && typeof language === 'string') patch.language = language;
  if (visibility && typeof visibility === 'string') patch.visibility = visibility;
  if (Object.keys(patch).length > 0) {
    await backendFetch(`/v1/admin/articles/${articleId}`, {
      method: 'PATCH',
      body: JSON.stringify(patch),
    });
    revalidatePath(`/articles/${articleId}`);
  }
}

export default async function ArticleDetailPage({ params }: { params: Promise<{ id: string }>; }) {
  const { id } = await params;
  const article = await getAdminArticle(id);

  if (!article) {
    notFound();
  }

  const [vocabulary, jobs, sentences] = await Promise.all([
    listArticleVocabulary(id),
    getArticleProcessingJobs(id),
    getArticleWorkplaceSentences(id),
  ]);

  return (
    <PageShell title={article.title}>
      {/* Metadata */}
      <dl className="article-meta">
        <div><dt>Status</dt><dd><span className="badge" data-status={article.status}>{article.status}</span></dd></div>
        <div><dt>Language</dt><dd>{article.language}</dd></div>
        <div><dt>Visibility</dt><dd><span className="badge" data-status={article.visibility}>{article.visibility}</span></dd></div>
        <div><dt>Processing error</dt><dd>{article.processing_error ?? 'None'}</dd></div>
      </dl>

      {/* Actions */}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <form className="inline-form" action={publishArticle}>
          <input type="hidden" name="articleId" value={article.id} />
          <button type="submit">Publish</button>
        </form>
        <form className="inline-form" action={reprocessArticle}>
          <input type="hidden" name="articleId" value={article.id} />
          <button type="submit">Reprocess</button>
        </form>
      </div>

      {/* Inline edit */}
      <section className="table-panel">
        <h2>Edit Metadata</h2>
        <form action={patchArticle} style={{ display: 'flex', flexWrap: 'wrap', gap: 12, alignItems: 'flex-end' }}>
          <input type="hidden" name="articleId" value={article.id} />
          <label>
            Title
            <input type="text" name="title" defaultValue={article.title} style={{ display: 'block', marginTop: 4 }} />
          </label>
          <label>
            Language
            <input type="text" name="language" defaultValue={article.language} style={{ display: 'block', marginTop: 4, width: 80 }} />
          </label>
          <label>
            Visibility
            <select name="visibility" defaultValue={article.visibility} style={{ display: 'block', marginTop: 4 }}>
              <option value="private">private</option>
              <option value="published">published</option>
            </select>
          </label>
          <button type="submit">Save</button>
        </form>
      </section>

      {/* Processing job history */}
      <section className="table-panel">
        <h2>Processing History</h2>
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Status</th>
              <th>Started</th>
              <th>Duration</th>
              <th>Error</th>
            </tr>
          </thead>
          <tbody>
            {jobs.length === 0 ? (
              <tr><td colSpan={5}><div className="empty-state">No processing jobs found.</div></td></tr>
            ) : jobs.map((job) => (
              <tr key={job.id}>
                <td data-label="#">{job.attempt_number}</td>
                <td data-label="Status"><span className="badge" data-status={job.status}>{job.status}</span></td>
                <td data-label="Started">{job.started_at ? new Date(job.started_at).toLocaleString() : '—'}</td>
                <td data-label="Duration">{job.duration_seconds != null ? `${job.duration_seconds.toFixed(1)}s` : '—'}</td>
                <td data-label="Error" title={job.error_message ?? undefined}>
                  {job.error_message ? job.error_message.slice(0, 80) : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {/* Vocabulary */}
      <section className="table-panel">
        <h2>Vocabulary ({vocabulary.length})</h2>
        <table>
          <thead>
            <tr>
              <th>Term</th>
              <th>Meaning</th>
              <th>Usage</th>
              <th>POS</th>
              <th>IPA</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {vocabulary.length === 0 ? (
              <tr>
                <td colSpan={6}><div className="empty-state">No vocabulary items available yet.</div></td>
              </tr>
            ) : vocabulary.map((item) => (
              <tr key={item.id}>
                <td data-label="Term">{item.display_term ?? 'Unknown'}</td>
                <td data-label="Meaning">{item.meaning_vi ?? '—'}</td>
                <td data-label="Usage">{item.example ?? item.example_vi ?? '—'}</td>
                <td data-label="POS">{item.part_of_speech ?? '—'}</td>
                <td data-label="IPA">{item.ipa ?? '—'}</td>
                <td data-label="Status"><span className="badge" data-status={item.status}>{item.status}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {/* Workplace Sentences */}
      {sentences.length > 0 && (
        <section className="table-panel">
          <h2>Workplace Sentences ({sentences.length})</h2>
          <table>
            <thead>
              <tr>
                <th>Sentence</th>
                <th>Topic</th>
                <th>Language</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {sentences.map((s) => (
                <tr key={s.id}>
                  <td data-label="Sentence">{s.sentence_text}</td>
                  <td data-label="Topic">{s.topic ?? '—'}</td>
                  <td data-label="Language">{s.language}</td>
                  <td data-label="Created">{new Date(s.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </PageShell>
  );
}
