import { getProficiencyProfile, normalizeDifficultyLevel } from './proficiency.js';

export class LiteLLMClient {
  constructor({ baseUrl, apiKey, model, fetchImpl = fetch, logger = console }) {
    this.baseUrl = baseUrl ? baseUrl.replace(/\/$/, '') : undefined;
    this.apiKey = apiKey;
    this.model = model;
    this.fetchImpl = fetchImpl;
    this.logger = logger;
  }

  async generateVocabulary({
    sourceLanguage = 'vi',
    targetLanguage = 'en',
    limit = 100,
    avoidTerms = [],
    difficultyLevel = 'A1'
  }) {
    const startedAt = Date.now();
    if (!this.baseUrl) {
      throw new Error('LiteLLM base URL is not configured. Set the LITELLM_BASE_URL environment variable.');
    }
    const profile = getProficiencyProfile({ language: targetLanguage });
    const resolvedDifficulty = normalizeDifficultyLevel(difficultyLevel, { language: targetLanguage }) ?? difficultyLevel;
    const userPromptLines = buildPromptLines({
      sourceLanguage,
      targetLanguage,
      limit,
      avoidTerms,
      profile,
      difficultyLevel: resolvedDifficulty
    });
    this.logger.debug?.('litellm_request_started', {
      source_language: sourceLanguage,
      target_language: targetLanguage,
      limit,
      difficulty_level: resolvedDifficulty,
      proficiency_scale: profile.scale,
      avoid_terms_count: avoidTerms.length
    });

    let response;
    try {
      response = await this.fetchImpl(`${this.baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(this.apiKey ? { authorization: `Bearer ${this.apiKey}` } : {})
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            {
              role: 'system',
              content:
                'Generate vocabulary for Vietnamese learners. Return valid JSON only.'
            },
            {
              role: 'user',
              content: userPromptLines.join('\n')
            }
          ],
          temperature: 0.5
        })
      });
    } catch (error) {
      this.logger.error?.('litellm_request_failed', {
        elapsed_ms: Date.now() - startedAt,
        error
      });
      throw error;
    }
    if (!response.ok) {
      this.logger.error?.('litellm_request_failed', {
        status_code: response.status,
        elapsed_ms: Date.now() - startedAt
      });
      throw new Error(`LiteLLM request failed: ${response.status}`);
    }
    const body = await response.json();
    this.logger.debug?.('litellm_request_completed', {
      status_code: response.status,
      elapsed_ms: Date.now() - startedAt
    });
    return body.choices?.[0]?.message?.content ?? '';
  }

  async generateArticleVocabularySuggestions({
    sourceLanguage = 'vi',
    targetLanguage = 'en',
    chunk,
    chunkIndex = 0,
    maxSuggestions = 10,
    articleTitle = null,
    articleLanguage = targetLanguage
  }) {
    const startedAt = Date.now();
    if (!this.baseUrl) {
      throw new Error('LiteLLM base URL is not configured. Set the LITELLM_BASE_URL environment variable.');
    }
    const profile = getProficiencyProfile({ language: targetLanguage });
    const difficultyLevel = getDefaultArticleDifficulty({ language: targetLanguage });
    const userPromptLines = buildArticleSuggestionPromptLines({
      sourceLanguage,
      targetLanguage,
      chunk,
      chunkIndex,
      maxSuggestions,
      profile,
      difficultyLevel,
      articleTitle,
      articleLanguage
    });

    this.logger.debug?.('litellm_article_suggestion_started', {
      source_language: sourceLanguage,
      target_language: targetLanguage,
      chunk_index: chunkIndex,
      max_suggestions: maxSuggestions,
      proficiency_scale: profile.scale
    });

    let response;
    try {
      response = await this.fetchImpl(`${this.baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(this.apiKey ? { authorization: `Bearer ${this.apiKey}` } : {})
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            {
              role: 'system',
              content:
                'Suggest article vocabulary for Vietnamese learners. Return valid JSON only.'
            },
            {
              role: 'user',
              content: userPromptLines.join('\n')
            }
          ],
          temperature: 0.4
        })
      });
    } catch (error) {
      this.logger.error?.('litellm_article_suggestion_failed', {
        elapsed_ms: Date.now() - startedAt,
        error
      });
      throw error;
    }

    if (!response.ok) {
      this.logger.error?.('litellm_article_suggestion_failed', {
        status_code: response.status,
        elapsed_ms: Date.now() - startedAt
      });
      throw new Error(`LiteLLM request failed: ${response.status}`);
    }

    const body = await response.json();
    this.logger.debug?.('litellm_article_suggestion_completed', {
      status_code: response.status,
      elapsed_ms: Date.now() - startedAt
    });
    return body.choices?.[0]?.message?.content ?? '';
  }

  async generateArticleWorkplaceSentenceSuggestions({
    sourceLanguage = 'vi',
    targetLanguage = 'en',
    chunk,
    chunkIndex = 0,
    maxSuggestions = 5,
    articleTitle = null,
    articleLanguage = targetLanguage
  }) {
    const startedAt = Date.now();
    if (!this.baseUrl) {
      throw new Error('LiteLLM base URL is not configured. Set the LITELLM_BASE_URL environment variable.');
    }
    const userPromptLines = buildArticleWorkplaceSentencePromptLines({
      sourceLanguage,
      targetLanguage,
      chunk,
      chunkIndex,
      maxSuggestions,
      articleTitle,
      articleLanguage
    });

    this.logger.debug?.('litellm_workplace_sentence_started', {
      source_language: sourceLanguage,
      target_language: targetLanguage,
      chunk_index: chunkIndex,
      max_suggestions: maxSuggestions
    });

    let response;
    try {
      response = await this.fetchImpl(`${this.baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(this.apiKey ? { authorization: `Bearer ${this.apiKey}` } : {})
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            {
              role: 'system',
              content:
                'Suggest practical workplace English sentences for Vietnamese learners. Return valid JSON only.'
            },
            {
              role: 'user',
              content: userPromptLines.join('\n')
            }
          ],
          temperature: 0.4
        })
      });
    } catch (error) {
      this.logger.error?.('litellm_workplace_sentence_failed', {
        elapsed_ms: Date.now() - startedAt,
        error
      });
      throw error;
    }

    if (!response.ok) {
      this.logger.error?.('litellm_workplace_sentence_failed', {
        status_code: response.status,
        elapsed_ms: Date.now() - startedAt
      });
      throw new Error(`LiteLLM request failed: ${response.status}`);
    }

    const body = await response.json();
    this.logger.debug?.('litellm_workplace_sentence_completed', {
      status_code: response.status,
      elapsed_ms: Date.now() - startedAt
    });
    return body.choices?.[0]?.message?.content ?? '';
  }
}

function buildPromptLines({
  sourceLanguage,
  targetLanguage,
  limit,
  avoidTerms,
  profile,
  difficultyLevel
}) {
  const difficultyLevels = profile.levels.join('/');
  if (profile.scale === 'hsk') {
    return [
      `Generate ${limit} ${targetLanguage} vocabulary words for ${sourceLanguage} speakers learning ${targetLanguage}.`,
      `Target proficiency scale is HSK and target level is ${difficultyLevel}.`,
      `Each item: term is a Chinese word/phrase (hanzi), language="${targetLanguage}", meaning_vi is the Vietnamese meaning, part_of_speech in English, Chinese does not use IPA so ipa MUST be empty, vietnamese_pronunciation MUST contain pinyin-style romanization, example is a natural ${targetLanguage} sentence using the term, example_vi is the Vietnamese translation of example, difficulty is one of ${difficultyLevels} and should equal ${difficultyLevel}, topics is an array of relevant topic strings, entry_type is one of "word"/"phrase"/"idiom" (word for single words, phrase for multi-word expressions, idiom for fixed expressions), blank_word is the single most semantically loaded content word of the phrase/idiom that appears verbatim in the example (null for word entry_type).`,
      avoidTerms.length > 0
        ? `Do not return any term from this forbidden list: ${avoidTerms.join(', ')}.`
        : 'Return terms that are different from previously generated results.',
      `Return a JSON array of ${limit} objects with exactly these fields: term, language, meaning_vi, part_of_speech, ipa, vietnamese_pronunciation, example, example_vi, difficulty, topics, entry_type, blank_word.`
    ];
  }

  return [
    `Generate ${limit} ${targetLanguage} vocabulary words for ${sourceLanguage} speakers learning ${targetLanguage}.`,
    `Target proficiency scale is CEFR and target level is ${difficultyLevel}.`,
    `Each item: term is a ${targetLanguage} word/phrase, language="${targetLanguage}", meaning_vi is the Vietnamese meaning, part_of_speech in English, ipa is the ${targetLanguage} IPA pronunciation, vietnamese_pronunciation is how to pronounce in Vietnamese phonetics, example is a ${targetLanguage} sentence using the term, example_vi is the Vietnamese translation of example, difficulty is one of ${difficultyLevels} and should equal ${difficultyLevel}, topics is an array of relevant topic strings, entry_type is one of "word"/"phrase"/"idiom" (word for single words, phrase for multi-word expressions, idiom for fixed expressions), blank_word is the single most semantically loaded content word of the phrase/idiom that appears verbatim in the example (null for word entry_type).`,
    avoidTerms.length > 0
      ? `Do not return any term from this forbidden list: ${avoidTerms.join(', ')}.`
      : 'Return terms that are different from previously generated results.',
    `Return a JSON array of ${limit} objects with exactly these fields: term, language, meaning_vi, part_of_speech, ipa, vietnamese_pronunciation, example, example_vi, difficulty, topics, entry_type, blank_word.`
  ];
}

function buildArticleSuggestionPromptLines({
  sourceLanguage,
  targetLanguage,
  chunk,
  chunkIndex,
  maxSuggestions,
  profile,
  difficultyLevel,
  articleTitle,
  articleLanguage
}) {
  const difficultyLevels = profile.levels.join('/');
  return [
    `Analyze article chunk ${chunkIndex + 1} and suggest up to ${maxSuggestions} useful ${targetLanguage} words or phrases for ${sourceLanguage} speakers.`,
    articleTitle ? `Article title: ${articleTitle}.` : null,
    `Article language is ${articleLanguage}. Target proficiency scale is ${profile.scale.toUpperCase()} and target level is ${difficultyLevel}.`,
    'Each suggestion must be directly supported by the chunk and should be useful for vocabulary study.',
    'Return a JSON array of objects with exactly these fields: term, language, meaning_vi, part_of_speech, ipa, vietnamese_pronunciation, example, example_vi, difficulty, level, topics, classification, suggestion_type.',
    `Use difficulty and level values from ${difficultyLevels} or the nearest valid level for the article language.`,
    'Use classification values like article_keyword, article_phrase, or article_concept when appropriate.',
    'Use suggestion_type word for single words and phrase for multiword expressions.',
    'Chunk text:',
    chunk
  ].filter(Boolean);
}

function buildArticleWorkplaceSentencePromptLines({
  sourceLanguage,
  targetLanguage,
  chunk,
  chunkIndex,
  maxSuggestions,
  articleTitle,
  articleLanguage
}) {
  return [
    `Analyze article chunk ${chunkIndex + 1} and suggest up to ${maxSuggestions} practical ${targetLanguage} workplace sentences for ${sourceLanguage} speakers.`,
    articleTitle ? `Article title: ${articleTitle}.` : null,
    `Article language is ${articleLanguage}. Only return sentences that are directly supported by the chunk and useful in workplace communication.`,
    'Each item must contain exactly these fields: text, language, meaning_vi, topic.',
    'Return only English sentences, keep them concise, natural, and professional, and avoid duplicates or unsafe content.',
    'Chunk text:',
    chunk
  ].filter(Boolean);
}

function getDefaultArticleDifficulty({ language }) {
  const profile = getProficiencyProfile({ language });
  return profile.defaultLevel;
}
