import { revalidatePath } from 'next/cache';

import { backendRequest } from '@/lib/backend';
import { listPendingVocabulary } from '@/lib/db';
import { formText, optionalFormText } from '@/lib/form';
import ActionForm from '@/components/ActionForm';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';
import StatusBadge from '@/components/StatusBadge';

export const dynamic = 'force-dynamic';

async function updateVocabularyItem(formData: FormData) {
  'use server';
  await backendRequest(`/v1/admin/vocabulary/${encodeURIComponent(formText(formData, 'itemId'))}`, {
    method: 'PATCH',
    body: { status: formText(formData, 'status'), review_note: optionalFormText(formData, 'review_note') },
  });
  revalidatePath('/review');
}

export default async function ReviewPage() {
  const items = await listPendingVocabulary();

  return (
    <PageShell title="Vocabulary Review">
      <section className="table-panel">
        <DataTable
          rows={items}
          rowKey={(item) => item.id}
          empty="No pending vocabulary items right now."
          columns={[
            { label: 'Article', render: (item) => item.article_title ?? '—' },
            { label: 'Term', render: (item) => item.display_term ?? '—' },
            { label: 'Meaning', render: (item) => item.meaning_vi ?? '—' },
            { label: 'Usage', render: (item) => item.example ?? item.example_vi ?? '—' },
            { label: 'POS', render: (item) => item.part_of_speech ?? '—' },
            { label: 'Status', render: (item) => <StatusBadge status={item.status} /> },
            {
              label: 'Actions',
              render: (item) => (
                <div className="stacked-actions">
                  <ActionForm action={updateVocabularyItem} fields={{ itemId: item.id, status: 'approved' }} label="Approve" />
                  <ActionForm action={updateVocabularyItem} fields={{ itemId: item.id, status: 'rejected' }} label="Reject">
                    <input name="review_note" placeholder="Reason" aria-label="Rejection reason" />
                  </ActionForm>
                </div>
              ),
            },
          ]}
        />
      </section>
    </PageShell>
  );
}
