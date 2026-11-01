import pkg from '../../package.json';
import { getAdminConfig } from '@/lib/config';
import SidebarNav from './SidebarNav';

export default function Sidebar() {
  const { envLabel } = getAdminConfig();

  return (
    <aside className="sidebar" aria-label="Sidebar">
      <div className="sidebar-brand" aria-label="Expat8">
        {/* eslint-disable-next-line @next/next/no-img-element -- static SVG, nothing for next/image to optimize */}
        <img className="brand-mark" src="/brand/expa8-mark.svg" alt="" aria-hidden="true" />
        <span>Expat8</span>
        <span className="sidebar-brand-sub">Admin</span>
      </div>
      <SidebarNav />
      <div className="sidebar-footer">
        <span>Expat8 Admin</span>
        <span className="muted">v{pkg.version} · {envLabel}</span>
      </div>
    </aside>
  );
}
