import { notFound } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { getMemorizationPassage } from '@/lib/db';
import { backendFetch } from '@/lib/backend';
import PageShell from '@/components/PageShell';
import ConfirmSubmitButton from '@/components/ConfirmSubmitButton';

export const dynamic = 'force-dynamic';

export default async function MemorizationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const passage = await getMemorizationPassage(id);
  if (!passage) notFound();

  async function publishPassage(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    await backendFetch(`/v1/admin/memorization/passages/${passageId}`, {
      method: 'PATCH',
      body: { visibility: 'published' },
    });
    revalidatePath(`/memorization/passages/${passageId}`);
    revalidatePath('/memorization/passages');
  }

  async function resegmentPassage(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    await backendFetch(`/v1/admin/memorization/passages/${passageId}/resegment`, {
      method: 'POST',
    });
    revalidatePath(`/memorization/passages/${passageId}`);
    revalidatePath('/memorization/passages');
  }

  async function updatePassage(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    const title = formData.get('title') as string;
    const language = formData.get('language') as string;
    const visibility = formData.get('visibility') as string;
    await backendFetch(`/v1/admin/memorization/passages/${passageId}`, {
      method: 'PATCH',
      body: { title, language, visibility },
    });
    revalidatePath(`/memorization/passages/${passageId}`);
    revalidatePath('/memorization/passages');
  }

  async function updateSegment(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    const segmentId = String(formData.get('segmentId') ?? '');
    const position = Number.parseInt(String(formData.get('position') ?? ''), 10);
    await backendFetch(`/v1/admin/memorization/segments/${segmentId}`, {
      method: 'PATCH',
      body: {
        text: String(formData.get('text') ?? ''),
        ...(Number.isNaN(position) ? {} : { position }),
      },
    });
    revalidatePath(`/memorization/passages/${passageId}`);
  }

  async function splitSegment(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    const segmentId = String(formData.get('segmentId') ?? '');
    const splitAt = Number.parseInt(String(formData.get('splitAt') ?? ''), 10);
    await backendFetch(`/v1/admin/memorization/segments/${segmentId}/split`, {
      method: 'POST',
      body: { split_at: splitAt },
    });
    revalidatePath(`/memorization/passages/${passageId}`);
  }

  async function mergeSegment(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    const segmentId = String(formData.get('segmentId') ?? '');
    const nextSegmentId = String(formData.get('nextSegmentId') ?? '');
    await backendFetch(`/v1/admin/memorization/segments/${segmentId}/merge`, {
      method: 'POST',
      body: { next_segment_id: nextSegmentId },
    });
    revalidatePath(`/memorization/passages/${passageId}`);
  }

  async function enrichPassage(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    await backendFetch(`/v1/admin/memorization/passages/${passageId}/enrich`, {
      method: 'PATCH',
    });
    revalidatePath(`/memorization/passages/${passageId}`);
  }

  async function retryPassage(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    await backendFetch(`/v1/admin/memorization/passages/${passageId}/retry`, {
      method: 'POST',
    });
    revalidatePath(`/memorization/passages/${passageId}`);
    revalidatePath('/memorization/passages');
  }

  async function retryEnrichment(formData: FormData) {
    'use server';
    const passageId = String(formData.get('passageId') ?? '');
    await backendFetch(`/v1/admin/memorization/passages/${passageId}/retry-enrichment`, {
      method: 'PATCH',
    });
    revalidatePath(`/memorization/passages/${passageId}`);
  }

  const segments = passage.segments ?? [];

  return (
    <PageShell title={passage.title}>
      {/* Error block */}
      {passage.processing_error && (
        <div style={{ background: '#fff3cd', border: '1px solid #ffc107', borderRadius: '4px', padding: '0.75rem 1rem', marginBottom: '1rem', color: '#856404' }}>
          <strong>Processing Error:</strong> {passage.processing_error}
        </div>
      )}

      {/* Metadata */}
      <section className="table-panel">
        <h2>Details</h2>
        <table>
          <tbody>
            <tr><td><strong>ID</strong></td><td>{passage.id}</td></tr>
            <tr><td><strong>Language</strong></td><td>{passage.language}</td></tr>
            <tr><td><strong>Owner</strong></td><td>{passage.owner_type}{passage.owner_user_id ? ` (${passage.owner_user_id})` : ''}</td></tr>
            <tr><td><strong>Visibility</strong></td><td><span className="badge" data-status={passage.visibility}>{passage.visibility}</span></td></tr>
            <tr><td><strong>Status</strong></td><td><span className="badge" data-status={passage.status}>{passage.status}</span></td></tr>
            <tr><td><strong>Enrichment</strong></td><td><span className="badge" data-status={passage.enrichment_status ?? 'none'}>{passage.enrichment_status ?? 'none'}</span></td></tr>
            <tr><td><strong>Segments</strong></td><td>{passage.segment_count ?? 0}</td></tr>
            <tr><td><strong>Created</strong></td><td>{passage.created_at}</td></tr>
            <tr><td><strong>Updated</strong></td><td>{passage.updated_at}</td></tr>
            {passage.processing_error && (
              <tr><td><strong>Error</strong></td><td style={{ color: 'red' }}>{passage.processing_error}</td></tr>
            )}
          </tbody>
        </table>
      </section>

      {/* Actions */}
      <section style={{ display: 'flex', gap: '0.5rem', margin: '1rem 0' }}>
        {passage.visibility !== 'published' && (
          <form action={publishPassage}>
            <input type="hidden" name="passageId" value={passage.id} />
            <ConfirmSubmitButton
              className="btn btn-primary"
              message="Publish this passage to all mobile users?"
            >
              Publish
            </ConfirmSubmitButton>
          </form>
        )}
        <form action={resegmentPassage}>
          <input type="hidden" name="passageId" value={passage.id} />
          <ConfirmSubmitButton
            className="btn"
            message="This will delete existing segments and queue the passage for segmentation again. Continue?"
          >
            Re-segment
          </ConfirmSubmitButton>
        </form>
        {(passage.status === 'segmented' || passage.status === 'published') && (
          <form action={enrichPassage}>
            <input type="hidden" name="passageId" value={passage.id} />
            <ConfirmSubmitButton
              className="btn"
              message="Generate IPA transcription and Vietnamese translation for all segments? This will not affect existing segments or user progress."
            >
              Enrich (IPA + Translation)
            </ConfirmSubmitButton>
          </form>
        )}
        {passage.status === 'failed' && (
          <form action={retryPassage}>
            <input type="hidden" name="passageId" value={passage.id} />
            <ConfirmSubmitButton
              className="btn btn-warning"
              message="Retry segmentation? This will reset the passage to pending and the worker will attempt segmentation again."
            >
              Retry Segmentation
            </ConfirmSubmitButton>
          </form>
        )}
        {passage.enrichment_status === 'failed' && (
          <form action={retryEnrichment}>
            <input type="hidden" name="passageId" value={passage.id} />
            <ConfirmSubmitButton
              className="btn btn-warning"
              message="Retry enrichment? This will re-queue IPA and translation generation without affecting existing segments or user progress."
            >
              Retry Enrichment
            </ConfirmSubmitButton>
          </form>
        )}
      </section>

      {/* Edit Form */}
      <section className="table-panel">
        <h2>Edit</h2>
        <form action={updatePassage} className="editor-form">
          <input type="hidden" name="passageId" value={passage.id} />
          <label>
            Title
            <input name="title" defaultValue={passage.title} required />
          </label>
          <label>
            Language
            <select name="language" defaultValue={passage.language}>
              <option value="en">English</option>
              <option value="zh">Chinese</option>
              <option value="vi">Vietnamese</option>
            </select>
          </label>
          <label>
            Visibility
            <select name="visibility" defaultValue={passage.visibility}>
              <option value="private">Private</option>
              <option value="published">Published</option>
            </select>
          </label>
          <button type="submit">Save</button>
        </form>
      </section>

      {/* Raw Text */}
      <section className="table-panel">
        <h2>Raw Text</h2>
        <pre style={{ whiteSpace: 'pre-wrap', maxHeight: '300px', overflow: 'auto', padding: '1rem', background: '#f5f5f5', borderRadius: '4px' }}>
          {passage.raw_text}
        </pre>
      </section>

      {/* Segments */}
      <section className="table-panel">
        <h2>Segments ({segments.length})</h2>
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Text</th>
              <th>IPA</th>
              <th>Translation</th>
              <th>Words</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {segments.length === 0 ? (
              <tr>
                <td colSpan={7}>
                  <div className="empty-state">No segments yet. Processing may be pending.</div>
                </td>
              </tr>
            ) : (
              segments.map((s, index) => {
                const nextSegment = segments[index + 1];
                const defaultSplitAt = Math.max(1, Math.floor(s.text.length / 2));
                return (
                  <tr key={s.id}>
                  <td>
                    <input form={`segment-${s.id}`} name="position" defaultValue={s.position} style={{ width: 64 }} />
                  </td>
                  <td style={{ minWidth: '400px' }}>
                    <textarea
                      form={`segment-${s.id}`}
                      name="text"
                      defaultValue={s.text}
                      rows={4}
                      style={{ width: '100%' }}
                    />
                  </td>
                  <td style={{ minWidth: '180px', fontSize: '0.85em', fontStyle: 'italic', color: s.ipa_text ? 'inherit' : '#999' }}>
                    {s.ipa_text ?? <em>Not generated</em>}
                  </td>
                  <td style={{ minWidth: '180px', fontSize: '0.85em', color: s.translation_text ? 'inherit' : '#999' }}>
                    {s.translation_text ?? <em>Not generated</em>}
                  </td>
                  <td>{s.word_count}</td>
                  <td>{new Date(s.created_at).toLocaleDateString()}</td>
                  <td>
                    <form id={`segment-${s.id}`} action={updateSegment}>
                      <input type="hidden" name="passageId" value={passage.id} />
                      <input type="hidden" name="segmentId" value={s.id} />
                      <button type="submit">Save</button>
                    </form>
                    <form action={splitSegment} style={{ marginTop: '0.5rem', display: 'flex', gap: '0.25rem' }}>
                      <input type="hidden" name="passageId" value={passage.id} />
                      <input type="hidden" name="segmentId" value={s.id} />
                      <input name="splitAt" defaultValue={defaultSplitAt} style={{ width: 72 }} aria-label="Split offset" />
                      <button type="submit">Split</button>
                    </form>
                    {nextSegment && (
                      <form action={mergeSegment} style={{ marginTop: '0.5rem' }}>
                        <input type="hidden" name="passageId" value={passage.id} />
                        <input type="hidden" name="segmentId" value={s.id} />
                        <input type="hidden" name="nextSegmentId" value={nextSegment.id} />
                        <button type="submit">Merge next</button>
                      </form>
                    )}
                  </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </section>
    </PageShell>
  );
}
