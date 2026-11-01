export function isSidebarLinkActive(pathname, href) {
  if (href === '/') {
    return pathname === '/';
  }

  return pathname === href || pathname.startsWith(`${href}/`);
}

/** The single most specific href that matches the path (so /articles/new does not also light up /articles). */
export function findActiveHref(pathname, hrefs) {
  return hrefs
    .filter((href) => isSidebarLinkActive(pathname, href))
    .sort((a, b) => b.length - a.length)[0] ?? null;
}
