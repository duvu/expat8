/**
 * Registration guard against mistyped email domains. A learner who signs up as
 * `me@gmal.com` ends up with an account nobody else can ever reach, and later
 * registers a second, correct one. Only exact, very likely typos of big
 * providers are listed so legitimate domains are never blocked; sign-in does
 * not use this check.
 */
const DOMAIN_TYPOS = new Map([
  ['gmal.com', 'gmail.com'],
  ['gmil.com', 'gmail.com'],
  ['gmai.com', 'gmail.com'],
  ['gmial.com', 'gmail.com'],
  ['gnail.com', 'gmail.com'],
  ['gmaill.com', 'gmail.com'],
  ['gmail.con', 'gmail.com'],
  ['gmail.cm', 'gmail.com'],
  ['gmail.comm', 'gmail.com'],
  ['hotmial.com', 'hotmail.com'],
  ['hotmal.com', 'hotmail.com'],
  ['hotmai.com', 'hotmail.com'],
  ['hotmail.con', 'hotmail.com'],
  ['yaho.com', 'yahoo.com'],
  ['yahooo.com', 'yahoo.com'],
  ['yahoo.con', 'yahoo.com'],
  ['outlok.com', 'outlook.com'],
  ['outloook.com', 'outlook.com'],
  ['outlook.con', 'outlook.com'],
  ['iclould.com', 'icloud.com'],
  ['icloud.con', 'icloud.com']
]);

/**
 * Returns the corrected identifier when `identifier` (already normalized) is an
 * email address on a known typo domain, otherwise null. Non-email identifiers
 * (phone numbers, usernames) never match.
 */
export function suggestIdentifierFix(identifier) {
  const text = String(identifier ?? '');
  const at = text.indexOf('@');
  if (at <= 0 || at !== text.lastIndexOf('@')) {
    return null;
  }
  const fixedDomain = DOMAIN_TYPOS.get(text.slice(at + 1));
  return fixedDomain ? `${text.slice(0, at)}@${fixedDomain}` : null;
}
