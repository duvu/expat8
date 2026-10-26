import { revalidatePath } from 'next/cache';

import { backendRequest } from '@/lib/backend';
import { listSpeakingPrompts } from '@/lib/db';
import { formText } from '@/lib/form';
import { SPEAKING_PROMPT_STATUS_OPTIONS } from '@/lib/options';
import ActionForm from '@/components/ActionForm';
import DataTable from '@/components/DataTable';
import FilterForm from '@/components/FilterForm';
import PageShell from '@/components/PageShell';
import Select from '@/components/Select';
import StatusBadge from '@/components/StatusBadge';

export const dynamic = 'force-dynamic';

async function updateSpeakingPromptStatus(formData: FormData) {
  'use server';
  await backendRequest(`/v1/admin/speaking-prompts/${encodeURIComponent(formText(formData, 'promptId'))}`, {
    method: 'PATCH',
    body: { status: formText(formData, 'status') },
  });
  revalidatePath('/speaking-prompts');
}

const missing = <em>missing</em>;

export default async function SpeakingPromptsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; missing?: string }>;
}) {
  const params = await searchParams;
  // No param → default to the review queue; an explicit empty value means "all".
  const status = params.status ?? 'pending_review';
  const missingRequired = params.missing === 'true';
  const items = await listSpeakingPrompts({ status: status || null, missingRequired });

  return (
    <PageShell title="Speaking Prompts">
      <section className="table-panel">
        <FilterForm>
          <Select label="Status" name="status" options={SPEAKING_PROMPT_STATUS_OPTIONS} defaultValue={status} emptyLabel="all" />
          <label className="checkbox-label">
            <input type="checkbox" name="missing" value="true" defaultChecked={missingRequired} />
            Missing required fields only
          </label>
        </FilterForm>
      </section>

      <section className="table-panel">
        <DataTable
          rows={items}
          rowKey={(item) => item.id}
          empty="No speaking prompts match the current filter."
          columns={[
            { label: 'Term', render: (item) => item.display_term ?? '—' },
            { label: 'Meaning', render: (item) => item.meaning_vi ?? '—' },
            { label: 'Target text', render: (item) => item.target_text || missing },
            { label: 'VI hint', render: (item) => item.vi_hint || missing },
            { label: 'Difficulty', render: (item) => item.difficulty ?? '—' },
            { label: 'Topic', render: (item) => item.topic ?? '—' },
            { label: 'Status', render: (item) => <StatusBadge status={item.status} /> },
            {
              label: 'Actions',
              render: (item) => (
                <div className="stacked-actions">
                  <ActionForm action={updateSpeakingPromptStatus} fields={{ promptId: item.id, status: 'approved' }} label="Approve" />
                  <ActionForm action={updateSpeakingPromptStatus} fields={{ promptId: item.id, status: 'rejected' }} label="Reject" />
                </div>
              ),
            },
          ]}
        />
      </section>
    </PageShell>
  );
}
