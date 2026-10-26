'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { deleteLogArchive, loadLogArchives } from '@/lib/ops-data';

function errorQuery(error: string) {
  return `?error=${encodeURIComponent(error)}`;
}

/** Deletes every archive the backend currently reports as expired. */
export async function deleteExpiredArchivesAction() {
  const { items, error: loadError } = await loadLogArchives();
  const errors = loadError ? [loadError] : [];
  for (const archive of items.filter((a) => a.retention_state === 'expired')) {
    const { error } = await deleteLogArchive(archive.id);
    if (error) errors.push(`${archive.id}: ${error}`);
  }
  revalidatePath('/ops/logs');
  revalidatePath('/ops');
  if (errors.length > 0) {
    redirect(`/ops/logs${errorQuery(errors.join('; '))}`);
  }
}

export async function deleteArchiveAction(formData: FormData) {
  const id = String(formData.get('archiveId') ?? '');
  const { error } = await deleteLogArchive(id);
  if (error) {
    redirect(`/ops/logs/${encodeURIComponent(id)}${errorQuery(error)}`);
  }
  revalidatePath('/ops/logs');
  revalidatePath('/ops');
  redirect('/ops/logs');
}
