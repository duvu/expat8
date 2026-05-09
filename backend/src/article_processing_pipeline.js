import { extractCandidateTerms } from './article_term_extractor.js';

export class ArticleProcessingPipeline {
  constructor({ store, enrichmentAdapter, logger = console }) {
    this.store = store;
    this.enrichmentAdapter = enrichmentAdapter;
    this.logger = logger;
  }

  async processArticle({ articleId, maxTerms = 20 }) {
    const article = await this.store.getArticleById({ articleId });
    if (!article) {
      return {
        success: false,
        classification: 'article_not_found',
        extracted_count: 0,
        accepted_count: 0,
        rejected_count: 0
      };
    }

    const extracted = extractCandidateTerms({
      text: article.cleaned_text ?? article.raw_text,
      maxTerms,
      language: article.language
    });

    const accepted = [];
    const rejected = [];

    for (const candidate of extracted) {
      const enriched = await this.enrichmentAdapter.enrichTerm({
        term: candidate.term,
        language: article.language,
        context: extractContextSnippet(article.raw_text, candidate.term),
        frequency: candidate.frequency,
        confidence: candidate.confidence
      });
      if (!enriched.ok) {
        rejected.push({
          term: candidate.term,
          classification: enriched.classification,
          reason: enriched.reason
        });
        continue;
      }
      accepted.push(enriched.item);
    }

    if (accepted.length > 0) {
      await this.store.persistArticleVocabulary({ articleId, items: accepted });
    }

    this.logger.info?.('article_processing_pipeline_completed', {
      article_id: articleId,
      extracted_count: extracted.length,
      accepted_count: accepted.length,
      rejected_count: rejected.length
    });

    return {
      success: true,
      classification: rejected.length > 0 ? 'partial_success' : 'success',
      extracted_count: extracted.length,
      accepted_count: accepted.length,
      rejected_count: rejected.length,
      rejected
    };
  }
}

function extractContextSnippet(rawText, term) {
  const text = String(rawText ?? '');
  const index = text.toLowerCase().indexOf(String(term).toLowerCase());
  if (index < 0) {
    return text.slice(0, 120);
  }
  const start = Math.max(0, index - 40);
  const end = Math.min(text.length, index + term.length + 80);
  return text.slice(start, end).trim();
}
