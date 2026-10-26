import SidebarNav from './SidebarNav';

export default function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-brand" aria-label="Expat8">
        {/* eslint-disable-next-line @next/next/no-img-element -- static SVG, nothing for next/image to optimize */}
        <img className="brand-mark" src="/brand/expa8-mark.svg" alt="" aria-hidden="true" />
        <span>Expat8</span>
      </div>
      <SidebarNav />
    </aside>
  );
}
