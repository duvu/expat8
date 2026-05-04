export function normalizeTerm(term) {
  return term.trim().toLocaleLowerCase('en-US').replace(/\s+/g, ' ');
}
