/** Trimmed string value of a form field ('' when absent). */
export function formText(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

/** Trimmed form value, or undefined when blank (so it is omitted from JSON bodies). */
export function optionalFormText(formData: FormData, name: string): string | undefined {
  return formText(formData, name) || undefined;
}

/** Query-string value, or null when blank. */
export function queryParam(value: string | undefined): string | null {
  return value?.trim() || null;
}
