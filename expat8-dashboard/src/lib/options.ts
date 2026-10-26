/** Shared select options (value, label). Values must match backend-accepted values. */

export type Option = readonly [value: string, label: string];

export const VISIBILITY_OPTIONS: Option[] = [
  ['private', 'Private'],
  ['published', 'Published'],
];

/** Languages accepted by the memorization admin API. */
export const PASSAGE_LANGUAGE_OPTIONS: Option[] = [
  ['en', 'English'],
  ['zh', 'Chinese'],
  ['vi', 'Vietnamese'],
];

/** Article statuses written by the backend (routes/admin.js + article worker). */
export const ARTICLE_STATUS_OPTIONS: Option[] = [
  ['pending_processing', 'Pending processing'],
  ['processing', 'Processing'],
  ['pending_review', 'Pending review'],
  ['processed', 'Processed'],
  ['published', 'Published'],
  ['processing_failed', 'Failed'],
  ['dead_lettered', 'Dead-lettered'],
];

export const PASSAGE_STATUS_OPTIONS: Option[] = [
  ['pending_segmentation', 'Pending segmentation'],
  ['segmenting', 'Segmenting'],
  ['segmented', 'Segmented'],
  ['published', 'Published'],
  ['failed', 'Failed'],
];

export const SPEAKING_PROMPT_STATUS_OPTIONS: Option[] = [
  ['pending_review', 'pending_review'],
  ['approved', 'approved'],
  ['rejected', 'rejected'],
];
