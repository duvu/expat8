export class LiteLLMClient {
  constructor({ baseUrl, apiKey, model, fetchImpl = fetch }) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey;
    this.model = model;
    this.fetchImpl = fetchImpl;
  }

  async generateVocabulary({
    sourceLanguage = 'vi',
    targetLanguage = 'en',
    limit = 5,
    avoidTerms = [],
    difficultyLevel = 'A1'
  }) {
    const response = await this.fetchImpl(`${this.baseUrl}/v1/chat/completions`, {
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
    if (!response.ok) {
      throw new Error(`LiteLLM request failed: ${response.status}`);
    }
    const body = await response.json();
    return body.choices?.[0]?.message?.content ?? '';
  }
}
