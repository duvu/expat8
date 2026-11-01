import type { ReactNode } from 'react';

import Icon, { type IconName } from './Icon';

type Props = {
  title: ReactNode;
  /** Guidance on what to do next. */
  hint?: ReactNode;
  icon?: IconName;
  tone?: 'default' | 'error';
  children?: ReactNode;
};

export default function EmptyState({ title, hint, icon = 'inbox', tone = 'default', children }: Props) {
  return (
    <div className={tone === 'error' ? 'empty-state error-state' : 'empty-state'}>
      <span className="empty-icon"><Icon name={tone === 'error' ? 'alert' : icon} size={22} /></span>
      <p className="empty-title">{title}</p>
      {hint && <p className="empty-hint">{hint}</p>}
      {children}
    </div>
  );
}
