'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { deleteLogArchive } from '@/lib/ops-data';

export async function deleteArchiveAction(id: string): Promise<{ error: string } | null> {
  const { error } = await deleteLogArchive(id);
  if (error) {
    return { error };
  }
  revalidatePath('/ops/logs');
  redirect('/ops/logs');
}
