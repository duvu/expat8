import { notFound } from 'next/navigation';
import { revalidatePath } from 'next/cache';

import { backendRequest } from '@/lib/backend';
import { getMemorizationPassage } from '@/lib/db';
import { formatDate, formatDateTime } from '@/lib/format';
import { formText } from '@/lib/form';
import { PASSAGE_LANGUAGE_OPTIONS, VISIBILITY_OPTIONS } from '@/lib/options';
import ActionForm from '@/components/ActionForm';
import DataTable from '@/components/DataTable';
import PageShell from '@/components/PageShell';
import Select from '@/components/Select';
import StatusBadge from '@/components/StatusBadge';

export const dynamic = 'force-dynamic';

const ADMIN = '/v1/admin/memorization';

function passageId(formData: FormData) {
  return formText(formData, 'passageId');
}

function passageUrl(formData: FormData) {
  return `${ADMIN}/passages/${encodeURIComponent(passageId(formData))}`;
}

function segmentUrl(formData: FormData) {
  return `${ADMIN}/segments/${encodeURIComponent(formText(formData, 'segmentId'))}`;
}

function revalidatePassage(formData: FormData, { list = false } = {}) {
  revalidatePath(`/memorization/passages/${passageId(formData)}`);
  if (list) revalidatePath('/memorization/passages');
}

async function publishPassage(formData: FormData) {
  'use server';
  await backendRequest(passageUrl(formData), { method: 'PATCH', body: { visibility: 'published' } });
  revalidatePassage(formData, { list: true });
}

async function resegmentPassage(formData: FormData) {
  'use server';
  await backendRequest(`${passageUrl(formData)}/resegment`, { method: 'POST' });
  revalidatePassage(formData, { list: true });
}

async function updatePassage(formData: FormData) {
  'use server';
  await backendRequest(passageUrl(formData), {
    method: 'PATCH',
    body: {
      title: formText(formData, 'title'),
      language: formText(formData, 'language'),
      visibility: formText(formData, 'visibility'),
    },
  });
  revalidatePassage(formData, { list: true });
}

async function enrichPassage(formData: FormData) {
  'use server';
  await backendRequest(`${passageUrl(formData)}/enrich`, { method: 'PATCH' });
  revalidatePassage(formData);
}

async function retryPassage(formData: FormData) {
  'use server';
  await backendRequest(`${passageUrl(formData)}/retry`, { method: 'POST' });
  revalidatePassage(formData, { list: true });
}

async function retryEnrichment(formData: FormData) {
  'use server';
  await backendRequest(`${passageUrl(formData)}/retry-enrichment`, { method: 'PATCH' });
  revalidatePassage(formData);
}

async function updateSegment(formData: FormData) {
  'use server';
  const position = Number.parseInt(formText(formData, 'position'), 10);
  await backendRequest(segmentUrl(formData), {
    method: 'PATCH',
    body: {
      text: String(formData.get('text') ?? ''),
      ...(Number.isNaN(position) ? {} : { position }),
    },
  });
  revalidatePassage(formData);
}

async function splitSegment(formData: FormData) {
  'use server';
  await backendRequest(`${segmentUrl(formData)}/split`, {
    method: 'POST',
    body: { split_at: Number.parseInt(formText(formData, 'splitAt'), 10) },
  });
  revalidatePassage(formData);
}

async function mergeSegment(formData: FormData) {
  'use server';
  await backendRequest(`${segmentUrl(formData)}/merge`, {
    method: 'POST',
    body: { next_segment_id: formText(formData, 'nextSegmentId') },
  });
  revalidatePassage(formData);
}

const notGenerated = <em className="muted">Not generated</em>;

export default async function MemorizationDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const passage = await getMemorizationPassage(id);
  if (!passage) notFound();

  const idField = { passageId: passage.id };
  const segments = passage.segments;
  const canEnrich = passage.status === 'segmented' || passage.status === 'published';

  return (
    <PageShell title={passage.title}>
      {passage.processing_error && (
        <div className="notice warning">
          <strong>Processing Error:</strong> {passage.processing_error}
        </div>
      )}

      <section className="table-panel">
        <h2>Details</h2>
        <dl className="article-meta">
          <div><dt>ID</dt><dd>{passage.id}</dd></div>
          <div><dt>Language</dt><dd>{passage.language}</dd></div>
          <div><dt>Owner</dt><dd>{passage.owner_type}{passage.owner_user_id ? ` (${passage.owner_user_id})` : ''}</dd></div>
          <div><dt>Visibility</dt><dd><StatusBadge status={passage.visibility} /></dd></div>
          <div><dt>Status</dt><dd><StatusBadge status={passage.status} /></dd></div>
          <div><dt>Enrichment</dt><dd><StatusBadge status={passage.enrichment_status} /></dd></div>
          <div><dt>Segments</dt><dd>{passage.segment_count ?? 0}</dd></div>
          <div><dt>Created</dt><dd>{formatDateTime(passage.created_at)}</dd></div>
          <div><dt>Updated</dt><dd>{formatDateTime(passage.updated_at)}</dd></div>
        </dl>
      </section>

      <div className="action-row">
        {passage.visibility !== 'published' && (
          <ActionForm
            action={publishPassage}
            fields={idField}
            label="Publish"
            buttonClassName="primary"
            confirm="Publish this passage to all mobile users?"
          />
        )}
        <ActionForm
          action={resegmentPassage}
          fields={idField}
          label="Re-segment"
          confirm="This will delete existing segments and queue the passage for segmentation again. Continue?"
        />
        {canEnrich && (
          <ActionForm
            action={enrichPassage}
            fields={idField}
            label="Enrich (IPA + Translation)"
            confirm="Generate IPA transcription and Vietnamese translation for all segments? This will not affect existing segments or user progress."
          />
        )}
        {passage.status === 'failed' && (
          <ActionForm
            action={retryPassage}
            fields={idField}
            label="Retry Segmentation"
            buttonClassName="warning"
            confirm="Retry segmentation? This will reset the passage to pending and the worker will attempt segmentation again."
          />
        )}
        {passage.enrichment_status === 'failed' && (
          <ActionForm
            action={retryEnrichment}
            fields={idField}
            label="Retry Enrichment"
            buttonClassName="warning"
            confirm="Retry enrichment? This will re-queue IPA and translation generation without affecting existing segments or user progress."
          />
        )}
      </div>

      <section className="table-panel">
        <h2>Edit</h2>
        <form action={updatePassage} className="editor-form">
          <input type="hidden" name="passageId" value={passage.id} />
          <label>
            Title
            <input name="title" defaultValue={passage.title} required />
          </label>
          <Select label="Language" name="language" options={PASSAGE_LANGUAGE_OPTIONS} defaultValue={passage.language} />
          <Select label="Visibility" name="visibility" options={VISIBILITY_OPTIONS} defaultValue={passage.visibility} />
          <button type="submit">Save</button>
        </form>
      </section>

      <section className="table-panel">
        <h2>Raw Text</h2>
        <pre className="raw-text">{passage.raw_text}</pre>
      </section>

      <section className="table-panel">
        <h2>Segments ({segments.length})</h2>
        <DataTable
          rows={segments}
          rowKey={(s) => s.id}
          empty="No segments yet. Processing may be pending."
          columns={[
            {
              label: '#',
              render: (s) => (
                <input form={`segment-${s.id}`} name="position" defaultValue={s.position} className="narrow-input" aria-label="Position" />
              ),
            },
            {
              label: 'Text',
              render: (s) => (
                <textarea form={`segment-${s.id}`} name="text" defaultValue={s.text} rows={4} className="segment-text" aria-label="Segment text" />
              ),
            },
            { label: 'IPA', render: (s) => <span className="segment-meta ipa">{s.ipa_text ?? notGenerated}</span> },
            { label: 'Translation', render: (s) => <span className="segment-meta">{s.translation_text ?? notGenerated}</span> },
            { label: 'Words', render: (s) => s.word_count },
            { label: 'Created', render: (s) => formatDate(s.created_at) },
            {
              label: 'Actions',
              render: (s, index) => {
                const segmentFields = { passageId: passage.id, segmentId: s.id };
                const nextSegment = segments[index + 1];
                return (
                  <div className="stacked-actions">
                    <form id={`segment-${s.id}`} className="inline-form" action={updateSegment}>
                      <input type="hidden" name="passageId" value={passage.id} />
                      <input type="hidden" name="segmentId" value={s.id} />
                      <button type="submit">Save</button>
                    </form>
                    <ActionForm action={splitSegment} fields={segmentFields} label="Split">
                      <input
                        name="splitAt"
                        defaultValue={Math.max(1, Math.floor(s.text.length / 2))}
                        className="narrow-input"
                        aria-label="Split offset"
                      />
                    </ActionForm>
                    {nextSegment && (
                      <ActionForm
                        action={mergeSegment}
                        fields={{ ...segmentFields, nextSegmentId: nextSegment.id }}
                        label="Merge next"
                      />
                    )}
                  </div>
                );
              },
            },
          ]}
        />
      </section>
    </PageShell>
  );
}
