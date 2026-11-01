'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { backendRequest, BackendError } from '@/lib/backend';
import { formText, optionalFormText } from '@/lib/form';

export type ResetPasswordState =
  | { status: 'idle' }
  | { status: 'error'; message: string }
  | { status: 'success'; identifier: string; revokedSessions: number; temporaryPassword?: string };

export type DeleteUserState = { status: 'idle' } | { status: 'error'; message: string };

const MIN_PASSWORD_LENGTH = 8;

function describeFailure(error: unknown, action: string): string {
  if (error instanceof BackendError) {
    if (error.status === 404) return 'This user no longer exists.';
    if (error.status === 403) return 'The backend refused the admin token.';
    if (error.message === 'confirmation_required') return 'The identifier did not match, so nothing was deleted.';
    return `${action} failed: ${error.message}`;
  }
  return `${action} failed. Check that the backend is reachable.`;
}

/** The temporary password only travels in this action's result, never in a URL or storage. */
export async function resetPasswordAction(_previous: ResetPasswordState, formData: FormData): Promise<ResetPasswordState> {
  const userId = formText(formData, 'userId');
  const newPassword = optionalFormText(formData, 'newPassword');
  if (newPassword !== undefined && newPassword.length < MIN_PASSWORD_LENGTH) {
    return { status: 'error', message: `The new password needs at least ${MIN_PASSWORD_LENGTH} characters.` };
  }
  try {
    const result = await backendRequest<{
      identifier: string;
      revoked_sessions: number;
      temporary_password?: string;
    }>(`/v1/admin/users/${encodeURIComponent(userId)}/reset-password`, {
      method: 'POST',
      body: newPassword === undefined ? {} : { new_password: newPassword },
    });
    return {
      status: 'success',
      identifier: result.identifier,
      revokedSessions: result.revoked_sessions,
      temporaryPassword: result.temporary_password,
    };
  } catch (error) {
    return { status: 'error', message: describeFailure(error, 'Password reset') };
  }
}

export async function deleteUserAction(_previous: DeleteUserState, formData: FormData): Promise<DeleteUserState> {
  const userId = formText(formData, 'userId');
  let identifier: string;
  try {
    const result = await backendRequest<{ identifier: string }>(`/v1/admin/users/${encodeURIComponent(userId)}`, {
      method: 'DELETE',
      body: { confirm: formText(formData, 'confirm') },
    });
    identifier = result.identifier;
  } catch (error) {
    return { status: 'error', message: describeFailure(error, 'Deleting the account') };
  }
  revalidatePath('/users');
  redirect(`/users?deleted=${encodeURIComponent(identifier)}`);
}
