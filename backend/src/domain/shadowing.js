// Shadowing video entry rules shared by both stores.

/**
 * Visibility and owner columns of a new entry: curated entries are public by
 * default and ownerless; saved entries belong to the user, or to the device
 * when signed out.
 */
export function shadowingEntryOwnership({ entryType, visibility, userId = null, deviceId = null }) {
  return {
    visibility: visibility ?? (entryType === 'curated' ? 'published' : 'private'),
    owner_user_id: entryType === 'saved' ? userId : null,
    owner_device_id: entryType === 'saved' && !userId ? deviceId : null
  };
}

/** Curated entries first, then most recently updated. */
export function compareShadowingEntries(left, right) {
  if (left.entry_type !== right.entry_type) {
    return left.entry_type === 'curated' ? -1 : 1;
  }
  return right.updated_at.localeCompare(left.updated_at);
}
