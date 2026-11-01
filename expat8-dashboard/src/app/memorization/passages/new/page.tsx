import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { backendRequest } from '@/lib/backend';
import { formText } from '@/lib/form';
import { PASSAGE_LANGUAGE_OPTIONS, VISIBILITY_OPTIONS } from '@/lib/options';
import PageShell from '@/components/PageShell';
import Select from '@/components/Select';

export const metadata = { title: 'New passage' };
export const dynamic = 'force-dynamic';

async function createPassage(formData: FormData) {
  'use server';
  const passage = await backendRequest<{ id: string }>('/v1/admin/memorization/passages', {
    method: 'POST',
    body: {
      title: formText(formData, 'title'),
      language: formText(formData, 'language'),
      // Not trimmed: the backend enforces the 50–20000 character bounds on the raw text.
      raw_text: String(formData.get('raw_text') ?? ''),
      visibility: formText(formData, 'visibility'),
    },
  });
  revalidatePath('/memorization/passages');
  redirect(`/memorization/passages/${passage.id}`);
}

export default function NewMemorizationPassagePage() {
  return (
    <PageShell title="New passage" description="Add a passage for learners to memorize." breadcrumbs={[{ label: 'Passages', href: '/memorization/passages' }, { label: 'New passage' }]}>
      <form action={createPassage} className="editor-form">
        <label>
          Title
          <input name="title" required placeholder="e.g. I Have a Dream" />
        </label>
        <Select label="Language" name="language" options={PASSAGE_LANGUAGE_OPTIONS} defaultValue="en" />
        <Select label="Visibility" name="visibility" options={VISIBILITY_OPTIONS} defaultValue="published" />
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
        <button type="submit" className="primary">Create Passage</button>
      </form>
    </PageShell>
  );
}
