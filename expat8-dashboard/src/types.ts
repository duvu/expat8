export type AdminArticle = {
  id: string;
  title: string;
  source_url: string | null;
  language: string;
  visibility: string;
  status: string;
  processing_error: string | null;
  created_at: string;
  updated_at: string;
};

export type VocabularyReviewItem = {
  id: string;
  status: string;
  review_note: string | null;
  reviewed_at: string | null;
  created_at: string;
  article_id?: string | null;
  article_title?: string | null;
  display_term?: string | null;
  meaning_vi?: string | null;
  example?: string | null;
  example_vi?: string | null;
  part_of_speech?: string | null;
  ipa?: string | null;
};
