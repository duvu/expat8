export class LiteLLMClient {
  constructor({ baseUrl, apiKey, model, fetchImpl = fetch }) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey;
    this.model = model;
    this.fetchImpl = fetchImpl;
  }

  async generateVocabulary({ sourceLanguage = 'vi', targetLanguage = 'en', limit = 5 }) {
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
              `source_language=${sourceLanguage}`,
              `target_language=${targetLanguage}`,
              `limit=${limit}`,
              'Each item must include term, language, meaning_vi, part_of_speech, ipa, vietnamese_pronunciation, example, example_vi, difficulty, topics.',
              'Examples must naturally include the generated term.'
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
