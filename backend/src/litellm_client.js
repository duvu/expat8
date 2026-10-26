import { getProficiencyProfile, normalizeDifficultyLevel } from './proficiency.js';

export class LiteLLMClient {
  constructor({ baseUrl, apiKey, model, timeoutMs = 120_000, fetchImpl = fetch, logger = console, rateLimiter = null }) {
    this.baseUrl = baseUrl ? baseUrl.replace(/\/$/, '') : undefined;
    this.apiKey = apiKey;
    this.model = model;
    // Router gateways (OmniRoute) may walk a long fallback chain; never hang a worker job forever.
    this.timeoutMs = timeoutMs;
    this.fetchImpl = fetchImpl;
    this.logger = logger;
    // Optional shared throttle; without one requests go straight to the gateway (tests, scripts).
    this.rateLimiter = rateLimiter;
  }

  /** Every gateway call goes through here so retries and rate limiting apply uniformly. */
  #fetch(url, init) {
    const send = () => this.fetchImpl(url, { ...init, signal: AbortSignal.timeout(this.timeoutMs) });
    return this.rateLimiter ? this.rateLimiter.run(send) : send();
  }

  /**
   * Generic chat completion — returns the raw OpenAI-style response object.
   * @param {{ messages: Array, temperature?: number, response_format?: object }} options
   */
  async chatCompletion({ messages, temperature = 0.7, response_format }) {
    if (!this.baseUrl) {
      throw new Error('LiteLLM base URL is not configured. Set the LITELLM_BASE_URL environment variable.');
    }
    const body = { model: this.model, messages, temperature };
    if (response_format) body.response_format = response_format;

    this.logger.debug?.('litellm_chat_completion_request', { message_count: messages.length });
    const startedAt = Date.now();
    let response;
    try {
      response = await this.#fetch(`${this.baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(this.apiKey ? { authorization: `Bearer ${this.apiKey}` } : {})
        },
        body: JSON.stringify(body)
      });
    } catch (error) {
      this.logger.error?.('litellm_chat_completion_fetch_error', { error, elapsed_ms: Date.now() - startedAt });
      throw error;
    }

    if (!response.ok) {
      const text = await response.text().catch(() => '');
      this.logger.error?.('litellm_chat_completion_http_error', { status: response.status, body: text });
      throw new Error(`LiteLLM HTTP ${response.status}: ${text}`);
    }

    const json = await response.json();
    this.logger.debug?.('litellm_chat_completion_response', { elapsed_ms: Date.now() - startedAt });
    return json;
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
    const resolvedDifficulty =
      normalizeDifficultyLevel(difficultyLevel, { language: targetLanguage }) ?? difficultyLevel;
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
      response = await this.#fetch(`${this.baseUrl}/v1/chat/completions`, {
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
              content: 'Generate vocabulary for Vietnamese learners. Return valid JSON only.'
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

  /**
   * Grades a web article for learners: CEFR level of its language, writing quality (1-5), and whether it
   * suits a general study corpus (no explicit/hateful/tragic-news/ad/listicle/sports-score content).
   */
  async assessArticle({ title, text }) {
    const response = await this.chatCompletion({
      temperature: 0.1,
      messages: [
        {
          role: 'system',
          content: 'You grade English reading material for Vietnamese learners. Return valid JSON only.'
        },
        {
          role: 'user',
          content: [
            'Assess this article for an English vocabulary-study corpus. Return one JSON object with exactly these fields:',
            '- cefr_level: the CEFR level (A1/A2/B1/B2/C1/C2) a learner needs to read it comfortably, judged from vocabulary and grammar, not from topic.',
            '- quality: integer 1-5 for clear, well-written, reusable everyday/work/general-knowledge language (1 = unusable).',
            '- suitable: false for explicit, violent, hateful, medical-advice, gambling, ad/sponsored, pure sports-score, or heavily local-politics content.',
            '- reason: one short sentence.',
            `Title: ${title}`,
            'Article:',
            String(text).slice(0, 3500)
          ].join('\n')
        }
      ]
    });
    const parsed = parseJsonObject(response.choices?.[0]?.message?.content ?? '');
    const level = String(parsed.cefr_level ?? '').trim().toUpperCase();
    return {
      cefr_level: normalizeDifficultyLevel(level, { language: 'en' }),
      quality: Math.max(0, Math.min(5, Math.round(Number(parsed.quality) || 0))),
      suitable: parsed.suitable === true,
      reason: typeof parsed.reason === 'string' ? parsed.reason.slice(0, 200) : null
    };
  }

  /** Suggests exact English Wikipedia article titles for the curated reading collection. */
  async suggestWikipediaTitles({ category, count = 8, avoid = [] }) {
    const subject = {
      speech: 'famous world speeches (the title of the Wikipedia article about the speech)',
      biography: 'influential historical figures and role models',
      history: 'important historical events, inventions, places and eras'
    }[category];
    const response = await this.chatCompletion({
      temperature: 0.6,
      messages: [
        { role: 'system', content: 'You pick reading material for English learners. Return valid JSON only.' },
        {
          role: 'user',
          content: [
            `List ${count} exact English Wikipedia article titles about ${subject}.`,
            'Choose well-known, uplifting or educational topics suitable for general learners.',
            `Do not repeat any of these: ${avoid.slice(0, 120).join('; ')}.`,
            'Return a JSON array of strings only.'
          ].join('\n')
        }
      ]
    });
    const raw = String(response.choices?.[0]?.message?.content ?? '')
      .trim()
      .replace(/^```(?:json)?/i, '')
      .replace(/```$/, '')
      .trim();
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed)
        ? parsed.filter((title) => typeof title === 'string' && title.trim()).map((title) => title.trim())
        : [];
    } catch {
      return [];
    }
  }

  async generateSubmittedVocabulary({
    sourceLanguage = 'vi',
    targetLanguage = 'en',
    term,
    difficultyLevel = 'A1'
  }) {
    const startedAt = Date.now();
    if (!this.baseUrl) {
      throw new Error('LiteLLM base URL is not configured. Set the LITELLM_BASE_URL environment variable.');
    }
    const profile = getProficiencyProfile({ language: targetLanguage });
    const resolvedDifficulty =
      normalizeDifficultyLevel(difficultyLevel, { language: targetLanguage }) ?? difficultyLevel;
    const userPromptLines = buildSubmittedVocabularyPromptLines({
      sourceLanguage,
      targetLanguage,
      term,
      profile,
      difficultyLevel: resolvedDifficulty
    });

    let response;
    try {
      response = await this.#fetch(`${this.baseUrl}/v1/chat/completions`, {
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
              content: 'Generate one exact vocabulary item for a submitted learner term. Return valid JSON only.'
            },
            {
              role: 'user',
              content: userPromptLines.join('\n')
            }
          ],
          temperature: 0.2
        })
      });
    } catch (error) {
      this.logger.error?.('litellm_submitted_vocabulary_failed', {
        elapsed_ms: Date.now() - startedAt,
        error
      });
      throw error;
    }

    if (!response.ok) {
      this.logger.error?.('litellm_submitted_vocabulary_failed', {
        status_code: response.status,
        elapsed_ms: Date.now() - startedAt
      });
      throw new Error(`LiteLLM request failed: ${response.status}`);
    }

    const body = await response.json();
    this.logger.debug?.('litellm_submitted_vocabulary_completed', {
      status_code: response.status,
      elapsed_ms: Date.now() - startedAt,
      target_language: targetLanguage
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
      response = await this.#fetch(`${this.baseUrl}/v1/chat/completions`, {
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
              content: 'Suggest article vocabulary for Vietnamese learners. Return valid JSON only.'
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
      response = await this.#fetch(`${this.baseUrl}/v1/chat/completions`, {
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
              content: 'Suggest practical workplace English sentences for Vietnamese learners. Return valid JSON only.'
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

function buildPromptLines({ sourceLanguage, targetLanguage, limit, avoidTerms, profile, difficultyLevel }) {
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

function buildSubmittedVocabularyPromptLines({ sourceLanguage: _sourceLanguage, targetLanguage, term, profile, difficultyLevel }) {
  const difficultyLevels = profile.levels.join('/');
  if (profile.scale === 'hsk') {
    return [
      `Generate exactly one ${targetLanguage} vocabulary item for the submitted learner term "${term}".`,
      `The final term MUST stay the same submitted term after normalization; do not replace it with a synonym or different expression.`,
      `Target proficiency scale is HSK and target level is ${difficultyLevel}.`,
      `Return a JSON array with exactly one object containing these fields: term, language, meaning_vi, part_of_speech, ipa, vietnamese_pronunciation, example, example_vi, difficulty, topics, entry_type, blank_word, explanation.`,
      `Set language to "${targetLanguage}". Chinese does not use IPA so ipa MUST be empty. vietnamese_pronunciation MUST contain pinyin-style romanization.`,
      `Difficulty must be one of ${difficultyLevels} and should equal ${difficultyLevel}. explanation is a short Vietnamese usage note. blank_word is null for word entry_type.`
    ];
  }

  return [
    `Generate exactly one ${targetLanguage} vocabulary item for the submitted learner term "${term}".`,
    `The final term MUST stay the same submitted term after normalization; do not replace it with a synonym or different expression.`,
    `Target proficiency scale is CEFR and target level is ${difficultyLevel}.`,
    `Return a JSON array with exactly one object containing these fields: term, language, meaning_vi, part_of_speech, ipa, vietnamese_pronunciation, example, example_vi, difficulty, topics, entry_type, blank_word, explanation.`,
    `Set language to "${targetLanguage}". explanation is a short Vietnamese usage note. entry_type is one of "word"/"phrase"/"idiom". blank_word is null for word entry_type.`
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
    `Article language is ${articleLanguage}. Proficiency scale is ${profile.scale.toUpperCase()}.`,
    'Each suggestion must be directly supported by the chunk and should be useful for vocabulary study.',
    `Judge each term's real ${profile.scale.toUpperCase()} level honestly (use ${difficultyLevel} only when unsure) and prefer terms above the most basic level: skip everyday beginner words a learner already knows.`,
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

function parseJsonObject(raw) {
  const text = String(raw).trim().replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  try {
    const parsed = JSON.parse(text);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) {
      return {};
    }
    try {
      return JSON.parse(match[0]);
    } catch {
      return {};
    }
  }
}
