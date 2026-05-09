import Link from 'next/link';
import { notFound } from 'next/navigation';
import { revalidatePath } from 'next/cache';

import { backendFetch } from '@/lib/backend';
import { getAdminArticle, listArticleVocabulary } from '@/lib/db';

export const dynamic = 'force-dynamic';

async function publishArticle(formData: FormData) {
  'use server';
  const articleId = String(formData.get('articleId') ?? '');
  await backendFetch(`/v1/admin/articles/${articleId}/publish`, { method: 'POST' });
  revalidatePath(`/articles/${articleId}`);
  revalidatePath('/');
}

async function reprocessArticle(formData: FormData) {
  'use server';
  const articleId = String(formData.get('articleId') ?? '');
  await backendFetch(`/v1/admin/articles/${articleId}/reprocess`, { method: 'POST' });
  revalidatePath(`/articles/${articleId}`);
  revalidatePath('/');
}

export default async function ArticleDetailPage({ params }: { params: Promise<{ id: string }>; }) {
  const { id } = await params;
  const article = await getAdminArticle(id);

  if (!article) {
    notFound();
  }

  const vocabulary = await listArticleVocabulary(id);

  return (
    <main>
      <header className="page-header">
        <Link href="/">Back</Link>
        <h1>{article.title}</h1>
      </header>

      <dl className="article-meta">
        <div><dt>Status</dt><dd><span className="badge" data-status={article.status}>{article.status}</span></dd></div>
        <div><dt>Language</dt><dd>{article.language}</dd></div>
        <div><dt>Visibility</dt><dd><span className="badge" data-status={article.visibility}>{article.visibility}</span></dd></div>
        <div><dt>Processing error</dt><dd>{article.processing_error ?? 'None'}</dd></div>
      </dl>

      <form className="inline-form" action={publishArticle}>
        <input type="hidden" name="articleId" value={article.id} />
        <button type="submit">Publish</button>
      </form>
      <form className="inline-form" action={reprocessArticle}>
        <input type="hidden" name="articleId" value={article.id} />
        <button type="submit">Reprocess</button>
      </form>

      <section className="table-panel">
        <h2>Vocabulary</h2>
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
                <td colSpan={6}>
                  <div className="empty-state">No vocabulary items are available for this article yet.</div>
                </td>
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
    </main>
  );
}
