export class LiteLLMClient {
  constructor({ baseUrl, apiKey, model, fetchImpl = fetch, logger = console }) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey;
    this.model = model;
    this.fetchImpl = fetchImpl;
    this.logger = logger;
  }

  async generateVocabulary({
    sourceLanguage = 'vi',
    targetLanguage = 'en',
    limit = 5,
    avoidTerms = [],
    difficultyLevel = 'A1'
  }) {
    const startedAt = Date.now();
    this.logger.debug?.('litellm_request_started', {
      source_language: sourceLanguage,
      target_language: targetLanguage,
      limit,
      difficulty_level: difficultyLevel,
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
              content: [
                `Generate ${limit} ${targetLanguage} vocabulary words for Vietnamese speakers learning ${targetLanguage}.`,
                `Target CEFR difficulty level is ${difficultyLevel}.`,
                `Each item: term is a ${targetLanguage} word/phrase, language="${targetLanguage}", meaning_vi is the Vietnamese meaning, part_of_speech in English, ipa is the ${targetLanguage} IPA pronunciation, vietnamese_pronunciation is how to pronounce in Vietnamese phonetics, example is a ${targetLanguage} sentence using the term, example_vi is the Vietnamese translation of example, difficulty is one of A1/A2/B1/B2/C1/C2 and should equal ${difficultyLevel}, topics is an array of relevant topic strings.`,
                avoidTerms.length > 0
                  ? `Do not return any term from this forbidden list: ${avoidTerms.join(', ')}.`
                  : 'Return terms that are different from previously generated results.',
                `Return a JSON array of ${limit} objects with exactly these fields: term, language, meaning_vi, part_of_speech, ipa, vietnamese_pronunciation, example, example_vi, difficulty, topics.`
              ].join('\n')
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
}
