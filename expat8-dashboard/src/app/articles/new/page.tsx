import { revalidatePath } from 'next/cache';

import { backendFetch } from '@/lib/backend';

async function createArticle(formData: FormData) {
  'use server';

  const payload = {
    title: String(formData.get('title') ?? '').trim(),
    language: String(formData.get('language') ?? '').trim(),
    raw_text: String(formData.get('raw_text') ?? '').trim(),
    source_url: String(formData.get('source_url') ?? '').trim() || undefined,
    visibility: String(formData.get('visibility') ?? 'private').trim()
  };

  await backendFetch('/v1/admin/articles', {
    method: 'POST',
    body: payload
  });

  revalidatePath('/');
}

export default function NewArticlePage() {
  return (
    <main>
      <h1>New article</h1>
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
        <label>
          Visibility
          <select name="visibility" defaultValue="private">
            <option value="private">Private</option>
            <option value="shared">Shared</option>
            <option value="published">Published</option>
          </select>
        </label>
        <label>
          Raw text
          <textarea name="raw_text" rows={18} required />
        </label>
        <button type="submit">Submit article</button>
      </form>
    </main>
  );
}
