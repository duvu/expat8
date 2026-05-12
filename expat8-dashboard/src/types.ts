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

export type ExamResult = {
  id: string;
  user_id: string;
  topic: string;
  language: string;
  difficulty_level: string | null;
  total_questions: number;
  correct_count: number;
  score_pct: number;
  passed: number;
  created_at: string;
  certificate_id: string | null;
};

export type UserRow = {
  id: string;
  identifier: string;
  display_name: string | null;
  created_at: string;
  last_activity: string | null;
  study_event_count: number;
};

export type UserDetail = {
  id: string;
  identifier: string;
  display_name: string | null;
  created_at: string;
  session_count: number;
  cached_word_count: number;
};

export type UserProficiency = {
  language: string;
  level: string;
  updated_at: string;
};

export type StudyEventSummary = {
  rating: string;
  count: number;
};

export type RecentStudyEvent = {
  id: string;
  word_id: string | null;
  local_word_id: string | null;
  rating: string;
  occurred_at: string;
};

export type DashboardSummaryStats = {
  total_users: number;
  total_study_events: number;
  active_last_7_days: number;
  total_words: number;
};

export type SpeakingPrompt = {
  id: string;
  word_sense_id: string;
  article_term_id: string | null;
  target_text: string | null;
  vi_hint: string | null;
  target_phrase: string | null;
  pronunciation_tip_vi: string | null;
  common_mistake_vi: string | null;
  difficulty: string | null;
  topic: string | null;
  status: string;
  reviewer_user_id: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
  display_term?: string | null;
  meaning_vi?: string | null;
};

