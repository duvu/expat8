// Spots accounts that probably belong to the same person (a mistyped email
// domain such as gmal.com, a one-letter slip) from rows already on screen.

const MIN_LOCAL_PART = 4;
const MIN_EMAIL_LENGTH = 6;

function splitEmail(identifier) {
  const at = identifier.indexOf('@');
  if (at <= 0 || at !== identifier.lastIndexOf('@')) return null;
  return { local: identifier.slice(0, at), domain: identifier.slice(at + 1) };
}

/** True when `a` and `b` differ by exactly one insertion, deletion or substitution. */
export function editDistanceIsOne(a, b) {
  if (a === b || Math.abs(a.length - b.length) > 1) return false;
  let i = 0;
  while (i < a.length && i < b.length && a[i] === b[i]) i += 1;
  if (a.length === b.length) return a.slice(i + 1) === b.slice(i + 1);
  const [shorter, longer] = a.length < b.length ? [a, b] : [b, a];
  return shorter.slice(i) === longer.slice(i + 1);
}

/** Why two normalised identifiers look alike, or null. Only email addresses are compared. */
export function lookalikeReason(a, b) {
  const left = splitEmail(a);
  const right = splitEmail(b);
  if (!left || !right || a === b) return null;
  if (left.local === right.local && left.local.length >= MIN_LOCAL_PART) return 'same_local_part';
  if (a.length >= MIN_EMAIL_LENGTH && editDistanceIsOne(a, b)) return 'one_character_apart';
  return null;
}

/**
 * Maps user id -> identifiers of the other rows it looks like. Users without a
 * lookalike are absent. O(n^2) is fine for one page of users.
 */
export function findLookalikes(users) {
  const result = new Map();
  const normalised = users.map((user) => ({ id: user.id, identifier: user.identifier.trim().toLowerCase() }));
  for (let i = 0; i < normalised.length; i += 1) {
    for (let j = i + 1; j < normalised.length; j += 1) {
      if (!lookalikeReason(normalised[i].identifier, normalised[j].identifier)) continue;
      for (const [from, to] of [[i, j], [j, i]]) {
        const list = result.get(normalised[from].id) ?? [];
        list.push(users[to].identifier);
        result.set(normalised[from].id, list);
      }
    }
  }
  return result;
}
