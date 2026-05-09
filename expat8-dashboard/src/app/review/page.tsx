import { revalidatePath } from 'next/cache';

import { backendFetch } from '@/lib/backend';
import { listPendingVocabulary } from '@/lib/db';

export const dynamic = 'force-dynamic';

async function updateVocabularyItem(formData: FormData) {
  'use server';

  const itemId = String(formData.get('itemId') ?? '');
  const status = String(formData.get('status') ?? '');
  const review_note = String(formData.get('review_note') ?? '').trim() || undefined;

  await backendFetch(`/v1/admin/vocabulary/${itemId}`, {
    method: 'PATCH',
    body: { status, review_note }
  });

  revalidatePath('/review');
}

export default async function ReviewPage() {
  const items = await listPendingVocabulary();

  return (
    <main>
      <h1>Vocabulary review</h1>
      <section className="table-panel">
      <table>
        <thead>
          <tr>
            <th>Article</th>
            <th>Term</th>
            <th>Meaning</th>
            <th>Usage</th>
            <th>POS</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {items.length === 0 ? (
            <tr>
              <td colSpan={7}>
                <div className="empty-state">No pending vocabulary items right now.</div>
              </td>
            </tr>
          ) : items.map((item) => (
            <tr key={item.id}>
              <td data-label="Article">{item.article_title ?? '—'}</td>
              <td data-label="Term">{item.display_term ?? '—'}</td>
              <td data-label="Meaning">{item.meaning_vi ?? '—'}</td>
              <td data-label="Usage">{item.example ?? item.example_vi ?? '—'}</td>
              <td data-label="POS">{item.part_of_speech ?? '—'}</td>
              <td data-label="Status"><span className="badge" data-status={item.status}>{item.status}</span></td>
              <td data-label="Actions">
                <div className="stacked-actions">
                  <form className="inline-form" action={updateVocabularyItem}>
                    <input type="hidden" name="itemId" value={item.id} />
                    <input type="hidden" name="status" value="approved" />
                    <button type="submit">Approve</button>
                  </form>
                  <form className="inline-form" action={updateVocabularyItem}>
                    <input type="hidden" name="itemId" value={item.id} />
                    <input type="hidden" name="status" value="rejected" />
                    <input name="review_note" placeholder="Reason" />
                    <button type="submit">Reject</button>
                  </form>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      </section>
    </main>
  );
}
