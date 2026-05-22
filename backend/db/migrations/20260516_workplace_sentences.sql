CREATE TABLE workplace_sentences (
  id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  normalized_text TEXT NOT NULL,
  language TEXT NOT NULL,
  meaning_vi TEXT NOT NULL,
  topic TEXT,
  generation_source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(language, normalized_text)
);

CREATE TABLE article_workplace_sentences (
  id TEXT PRIMARY KEY,
  article_id TEXT NOT NULL,
  workplace_sentence_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(article_id, workplace_sentence_id),
  FOREIGN KEY (article_id) REFERENCES articles(id),
  FOREIGN KEY (workplace_sentence_id) REFERENCES workplace_sentences(id)
);

CREATE INDEX idx_workplace_sentences_language_updated
  ON workplace_sentences(language, updated_at DESC);

CREATE INDEX idx_article_workplace_sentences_article
  ON article_workplace_sentences(article_id);

CREATE INDEX idx_article_workplace_sentences_sentence
  ON article_workplace_sentences(workplace_sentence_id);
