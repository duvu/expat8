'use client';

import { useActionState, useState } from 'react';

import {
  deleteUserAction,
  resetPasswordAction,
  type DeleteUserState,
  type ResetPasswordState,
} from '@/app/users/[id]/actions';
import ConfirmSubmitButton from './ConfirmSubmitButton';

const idleReset: ResetPasswordState = { status: 'idle' };
const idleDelete: DeleteUserState = { status: 'idle' };

/** Mirrors the backend rule: the identifier must be repeated exactly (case-insensitive). */
function matchesIdentifier(typed: string, identifier: string) {
  return typed.trim().toLowerCase() === identifier.toLowerCase();
}

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className="small"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(text);
          setCopied(true);
          setTimeout(() => setCopied(false), 2000);
        } catch {
          setCopied(false);
        }
      }}
    >
      {copied ? 'Copied' : 'Copy'}
    </button>
  );
}

function ResetPasswordForm({ userId }: { userId: string }) {
  const [state, action, pending] = useActionState(resetPasswordAction, idleReset);
  return (
    <div className="account-action">
      <div className="panel-heading">
        <h3>Reset password</h3>
        <p className="muted">Sets a new password and signs the learner out on every device.</p>
      </div>
      <form action={action}>
        <input type="hidden" name="userId" value={userId} />
        <label>
          <span>New password (optional)</span>
          <input
            type="password"
            name="newPassword"
            autoComplete="new-password"
            minLength={8}
            placeholder="Leave empty to generate a temporary password"
          />
        </label>
        <div className="form-actions">
          <ConfirmSubmitButton
            className="primary"
            message="Reset this learner's password? All of their sessions will be revoked."
          >
            {pending ? 'Resetting…' : 'Reset password'}
          </ConfirmSubmitButton>
        </div>
      </form>

      {state.status === 'error' && <p className="notice danger" role="alert">{state.message}</p>}
      {state.status === 'success' && (
        <div className="notice success" role="status">
          <p>
            <strong>Password reset for {state.identifier}.</strong> {state.revokedSessions.toLocaleString()} session
            {state.revokedSessions === 1 ? '' : 's'} revoked; they must sign in again.
          </p>
          {state.temporaryPassword ? (
            <>
              <div className="secret-box">
                <code aria-label="Temporary password">{state.temporaryPassword}</code>
                <CopyButton text={state.temporaryPassword} />
              </div>
              <p className="muted">
                Shown once. It is not stored anywhere, so copy it now and pass it to the learner privately.
              </p>
            </>
          ) : (
            <p className="muted">The password you typed is now active.</p>
          )}
        </div>
      )}
    </div>
  );
}

function DeleteUserForm({ userId, identifier }: { userId: string; identifier: string }) {
  const [state, action, pending] = useActionState(deleteUserAction, idleDelete);
  const [typed, setTyped] = useState('');
  return (
    <div className="account-action danger-zone">
      <div className="panel-heading">
        <h3>Delete account</h3>
        <p className="muted">
          Permanently removes the account, its sessions, study, speaking, game and exam history, word states, owned
          content and anonymous data from its devices. This cannot be undone.
        </p>
      </div>
      <form action={action}>
        <input type="hidden" name="userId" value={userId} />
        <label>
          <span>Type <strong>{identifier}</strong> to confirm</span>
          <input
            type="text"
            name="confirm"
            value={typed}
            onChange={(event) => setTyped(event.target.value)}
            autoComplete="off"
            autoCapitalize="off"
            spellCheck={false}
          />
        </label>
        <div className="form-actions">
          <button type="submit" className="danger" disabled={pending || !matchesIdentifier(typed, identifier)}>
            {pending ? 'Deleting…' : 'Delete account permanently'}
          </button>
        </div>
      </form>
      {state.status === 'error' && <p className="notice danger" role="alert">{state.message}</p>}
    </div>
  );
}

export default function AccountActions({ userId, identifier }: { userId: string; identifier: string }) {
  return (
    <section className="table-panel account-actions">
      <h2>Account actions</h2>
      <div className="account-actions-grid">
        <ResetPasswordForm userId={userId} />
        <DeleteUserForm userId={userId} identifier={identifier} />
      </div>
    </section>
  );
}
