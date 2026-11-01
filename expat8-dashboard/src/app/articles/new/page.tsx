import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { backendRequest } from '@/lib/backend';
import { formText, optionalFormText } from '@/lib/form';
import { VISIBILITY_OPTIONS } from '@/lib/options';
import PageShell from '@/components/PageShell';
import Select from '@/components/Select';

export const metadata = { title: 'New article' };
export const dynamic = 'force-dynamic';

async function createArticle(formData: FormData) {
  'use server';

  const article = await backendRequest<{ id: string }>('/v1/admin/articles', {
    method: 'POST',
    body: {
      title: formText(formData, 'title'),
      language: formText(formData, 'language'),
      raw_text: formText(formData, 'raw_text'),
      source_url: optionalFormText(formData, 'source_url'),
      visibility: formText(formData, 'visibility') || 'private',
    },
  });

  revalidatePath('/articles');
  redirect(`/articles/${article.id}`);
}

export default function NewArticlePage() {
  return (
    <PageShell title="New article" description="Submit text for processing into vocabulary and sentences." breadcrumbs={[{ label: 'Articles', href: '/articles' }, { label: 'New article' }]}>
      <form className="editor-form" action={createArticle}>
        <label>
          Title
          <input name="title" required />
        </label>
        <label>
          Language
          <input name="language" defaultValue="en" required />
        </label>
        <label>
          Source URL
          <input name="source_url" type="url" />
        </label>
        <Select label="Visibility" name="visibility" options={VISIBILITY_OPTIONS} defaultValue="private" />
        <label>
          Raw text
          <textarea name="raw_text" rows={18} required />
        </label>
        <button type="submit" className="primary">Submit article</button>
      </form>
    </PageShell>
  );
}
