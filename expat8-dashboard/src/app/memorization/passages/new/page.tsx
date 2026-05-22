import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { backendFetch } from '@/lib/backend';
import PageShell from '@/components/PageShell';

export default function NewMemorizationPassagePage() {
  async function createPassage(formData: FormData) {
    'use server';
    const title = formData.get('title') as string;
    const language = formData.get('language') as string;
    const raw_text = formData.get('raw_text') as string;
    const visibility = formData.get('visibility') as string;

    const response = await backendFetch('/v1/admin/memorization/passages', {
      method: 'POST',
      body: { title, language, raw_text, visibility },
    });
    const passage = await response.json();
    revalidatePath('/memorization/passages');
    redirect(`/memorization/passages/${passage.id}`);
  }

  return (
    <PageShell title="New Memorization Passage">
      <form action={createPassage} className="editor-form">
        <label>
          Title
          <input name="title" required placeholder="e.g. I Have a Dream" />
        </label>

        <label>
          Language
          <select name="language" defaultValue="en">
            <option value="en">English</option>
            <option value="zh">Chinese</option>
            <option value="vi">Vietnamese</option>
          </select>
        </label>

        <label>
          Visibility
          <select name="visibility" defaultValue="published">
            <option value="private">Private</option>
            <option value="published">Published</option>
          </select>
        </label>

        <label>
          Passage Text
          <textarea
            name="raw_text"
            required
            minLength={50}
            maxLength={20000}
            rows={12}
            placeholder="Paste the full passage text here (50-20000 characters)..."
          />
        </label>

        <button type="submit">Create Passage</button>
      </form>
    </PageShell>
  );
}
