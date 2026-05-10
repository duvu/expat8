import { revalidatePath } from 'next/cache';

import { backendFetch } from '@/lib/backend';
import { listSpeakingPrompts } from '@/lib/db';

export const dynamic = 'force-dynamic';

async function updateSpeakingPrompt(formData: FormData) {
  'use server';

  const promptId = String(formData.get('promptId') ?? '');
  const status = String(formData.get('status') ?? '');
  const target_text = String(formData.get('target_text') ?? '').trim() || undefined;
  const vi_hint = String(formData.get('vi_hint') ?? '').trim() || undefined;

  const patch: Record<string, string> = { status };
  if (target_text !== undefined) patch.target_text = target_text;
  if (vi_hint !== undefined) patch.vi_hint = vi_hint;

  await backendFetch(`/v1/admin/speaking-prompts/${promptId}`, {
    method: 'PATCH',
    body: patch
  });

  revalidatePath('/speaking-prompts');
}

export default async function SpeakingPromptsPage({
  searchParams
}: {
  searchParams?: Promise<{ status?: string; missing?: string }>;
}) {
  const params = await searchParams;
  const status = params?.status ?? 'pending_review';
  const missingRequired = params?.missing === 'true';

  const items = await listSpeakingPrompts({ status, missingRequired });

  const statusOptions = ['pending_review', 'approved', 'rejected'];

  return (
    <main>
      <h1>Speaking prompt review</h1>

      <div className="filter-bar">
        <form method="GET" style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
          <label>
            Status:{' '}
            <select name="status" defaultValue={status}>
              {statusOptions.map((s) => (
                <option key={s} value={s}>{s}</option>
              ))}
              <option value="">all</option>
            </select>
          </label>
          <label>
            <input type="checkbox" name="missing" value="true" defaultChecked={missingRequired} />{' '}
            Missing required fields only
          </label>
          <button type="submit">Filter</button>
        </form>
      </div>

      <section className="table-panel">
        <table>
          <thead>
            <tr>
              <th>Term</th>
              <th>Meaning</th>
              <th>Target text</th>
              <th>VI hint</th>
              <th>Difficulty</th>
              <th>Topic</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {items.length === 0 ? (
              <tr>
                <td colSpan={8}>
                  <div className="empty-state">No speaking prompts match the current filter.</div>
                </td>
              </tr>
            ) : items.map((item) => (
              <tr key={item.id}>
                <td data-label="Term">{item.display_term ?? '—'}</td>
                <td data-label="Meaning">{item.meaning_vi ?? '—'}</td>
                <td data-label="Target text">{item.target_text ?? <em>missing</em>}</td>
                <td data-label="VI hint">{item.vi_hint ?? <em>missing</em>}</td>
                <td data-label="Difficulty">{item.difficulty ?? '—'}</td>
                <td data-label="Topic">{item.topic ?? '—'}</td>
                <td data-label="Status">
                  <span className="badge" data-status={item.status}>{item.status}</span>
                </td>
                <td data-label="Actions">
                  <div className="stacked-actions">
                    <form className="inline-form" action={updateSpeakingPrompt}>
                      <input type="hidden" name="promptId" value={item.id} />
                      <input type="hidden" name="status" value="approved" />
                      <button type="submit">Approve</button>
                    </form>
                    <form className="inline-form" action={updateSpeakingPrompt}>
                      <input type="hidden" name="promptId" value={item.id} />
                      <input type="hidden" name="status" value="rejected" />
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
