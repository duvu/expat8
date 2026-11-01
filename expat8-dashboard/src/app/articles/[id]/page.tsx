import { notFound } from 'next/navigation';
import { revalidatePath } from 'next/cache';

import { backendRequest } from '@/lib/backend';
import { getAdminArticle, listArticleVocabulary } from '@/lib/db';
import { getArticleProcessingJobs, getArticleWorkplaceSentences } from '@/lib/analytics';
import { formatSeconds, truncate } from '@/lib/format';
import { formText } from '@/lib/form';
import { VISIBILITY_OPTIONS } from '@/lib/options';
import ActionForm from '@/components/ActionForm';
import DateTime from '@/components/DateTime';
import DataTable from '@/components/DataTable';
import LanguageChip from '@/components/LanguageChip';
import PageShell from '@/components/PageShell';
import Select from '@/components/Select';
import StatusBadge from '@/components/StatusBadge';

export const metadata = { title: 'Article' };
export const dynamic = 'force-dynamic';

function articlePath(formData: FormData) {
  return `/v1/admin/articles/${encodeURIComponent(formText(formData, 'articleId'))}`;
}

function revalidateArticle(formData: FormData) {
  revalidatePath(`/articles/${formText(formData, 'articleId')}`);
  revalidatePath('/articles');
}

async function publishArticle(formData: FormData) {
  'use server';
  await backendRequest(`${articlePath(formData)}/publish`, { method: 'POST' });
  revalidateArticle(formData);
}

async function reprocessArticle(formData: FormData) {
  'use server';
  await backendRequest(`${articlePath(formData)}/reprocess`, { method: 'POST' });
  revalidateArticle(formData);
}

async function patchArticle(formData: FormData) {
  'use server';
  const patch: Record<string, string> = {};
  for (const field of ['title', 'language', 'visibility']) {
    const value = formText(formData, field);
    if (value) patch[field] = value;
  }
  if (Object.keys(patch).length > 0) {
    await backendRequest(articlePath(formData), { method: 'PATCH', body: patch });
    revalidateArticle(formData);
  }
}

export default async function ArticleDetailPage({ params }: { params: Promise<{ id: string }> }) {
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
  const idField = { articleId: article.id };

  return (
    <PageShell title={article.title} breadcrumbs={[{ label: 'Articles', href: '/articles' }, { label: article.title }]}>
      <dl className="article-meta">
        <div><dt>Status</dt><dd><StatusBadge status={article.status} /></dd></div>
        <div><dt>Language</dt><dd><LanguageChip code={article.language} /></dd></div>
        <div><dt>Visibility</dt><dd><StatusBadge status={article.visibility} /></dd></div>
        <div><dt>Processing error</dt><dd>{article.processing_error ?? 'None'}</dd></div>
      </dl>

      <div className="action-row">
        <ActionForm action={publishArticle} fields={idField} label="Publish" buttonClassName="primary" />
        <ActionForm action={reprocessArticle} fields={idField} label="Reprocess" />
      </div>

      <section className="table-panel">
        <h2>Edit metadata</h2>
        <form action={patchArticle} className="filter-form">
          <input type="hidden" name="articleId" value={article.id} />
          <label>
            Title
            <input type="text" name="title" defaultValue={article.title} />
          </label>
          <label>
            Language
            <input type="text" name="language" defaultValue={article.language} />
          </label>
          <Select label="Visibility" name="visibility" options={VISIBILITY_OPTIONS} defaultValue={article.visibility} />
          <button type="submit">Save</button>
        </form>
      </section>

      <section className="table-panel">
        <h2>Processing history</h2>
        <DataTable
          rows={jobs}
          rowKey={(job) => job.id}
          empty="No processing jobs found."
          columns={[
            { label: 'Attempts', numeric: true, render: (job) => job.attempt_count },
            { label: 'Status', render: (job) => <StatusBadge status={job.status} /> },
            { label: 'Started', nowrap: true, render: (job) => <DateTime value={job.started_at} /> },
            { label: 'Duration', numeric: true, render: (job) => formatSeconds(job.duration_s) },
            {
              label: 'Error',
              render: (job) => job.error_message
                ? <span title={job.error_message}>{truncate(job.error_message, 80)}</span>
                : '—',
            },
          ]}
        />
      </section>

      <section className="table-panel">
        <h2>Vocabulary ({vocabulary.length})</h2>
        <DataTable
          rows={vocabulary}
          rowKey={(item) => item.id}
          empty="No vocabulary items available yet."
          columns={[
            { label: 'Term', render: (item) => item.display_term ?? 'Unknown' },
            { label: 'Meaning', render: (item) => item.meaning_vi ?? '—' },
            { label: 'Usage', render: (item) => item.example ?? '—' },
            { label: 'POS', render: (item) => item.part_of_speech ?? '—' },
            { label: 'IPA', render: (item) => item.ipa ?? '—' },
            { label: 'Status', render: (item) => <StatusBadge status={item.status} /> },
          ]}
        />
      </section>

      {sentences.length > 0 && (
        <section className="table-panel">
          <h2>Workplace Sentences ({sentences.length})</h2>
          <DataTable
            rows={sentences}
            rowKey={(s) => s.id}
            empty="No workplace sentences."
            columns={[
              { label: 'Sentence', render: (s) => s.text },
              { label: 'Topic', render: (s) => s.topic ?? '—' },
              { label: 'Language', render: (s) => <LanguageChip code={s.language} /> },
              { label: 'Created', nowrap: true, render: (s) => <DateTime value={s.created_at} dateOnly /> },
            ]}
          />
        </section>
      )}
    </PageShell>
  );
}
