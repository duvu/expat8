'use server';

import { revalidatePath } from 'next/cache';

import { deleteLogArchive } from '@/lib/ops-data';

export async function deleteExpiredArchivesAction(ids: string[]): Promise<{ error: string | null }> {
  const errors: string[] = [];
  for (const id of ids) {
    const { error } = await deleteLogArchive(id);
    if (error) {
      errors.push(`${id}: ${error}`);
    }
  }
  revalidatePath('/ops/logs');
  return { error: errors.length > 0 ? errors.join('; ') : null };
}
