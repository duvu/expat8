import type { ReactNode } from 'react';

import ConfirmSubmitButton from './ConfirmSubmitButton';

type Props = {
  action: (formData: FormData) => Promise<void>;
  /** Hidden inputs sent with the submit. */
  fields?: Record<string, string>;
  /** Submit button content. */
  label: ReactNode;
  /** When set, the browser asks for confirmation before submitting. */
  confirm?: string;
  buttonClassName?: string;
  /** Extra visible inputs rendered before the button. */
  children?: ReactNode;
};

/** One-button server-action form (publish, approve, retry, ...). */
export default function ActionForm({ action, fields = {}, label, confirm, buttonClassName, children }: Props) {
  return (
    <form className="inline-form" action={action}>
      {Object.entries(fields).map(([name, value]) => (
        <input key={name} type="hidden" name={name} value={value} />
      ))}
      {children}
      {confirm ? (
        <ConfirmSubmitButton className={buttonClassName} message={confirm}>{label}</ConfirmSubmitButton>
      ) : (
        <button type="submit" className={buttonClassName}>{label}</button>
      )}
    </form>
  );
}
