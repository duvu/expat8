const ENRICHMENT_SYSTEM_PROMPT = `You are a language learning assistant specializing in English phonetics and Vietnamese translation.
Given a list of English text segments, produce IPA transcription, Vietnamese translation, and Vietnamese phonetic reading for each segment.

For IPA:
- Use standard IPA notation
- Enclose the full segment transcription in forward slashes: /like this/
- Use American English pronunciation

For translation:
- Produce a natural, accurate Vietnamese translation of each segment
- Keep the translation concise but complete

For viet_reading (cách đọc):
- Write how to pronounce the English segment using Vietnamese phonetic conventions
- Use Vietnamese syllable approximations so a Vietnamese speaker can read it aloud
- Example: "for score and seven years ago" → "fo sco ren xê-vần di-ơz ơ-gâu"
- Keep it readable and phonetically close to natural English speech

Return a JSON array with one object per segment, in the same order as the input.
Each object must have "ipa" (string), "translation" (string), and "viet_reading" (string).

Example output:
[
  {"ipa": "/fɔːr skɔːr ænd ˈsɛvən jɪrz əˈɡoʊ/", "translation": "Bốn mươi bảy năm trước,", "viet_reading": "fo sco ren xê-vần di-ơz ơ-gâu"},
  {"ipa": "/ðæt aɪv bɪn ˈtɜːrnɪŋ ˈoʊvər ɪn maɪ maɪnd ˈɛvər sɪns/", "translation": "mà tôi đã suy nghĩ mãi từ đó đến nay.", "viet_reading": "đét ai-v bin tơ-ning âu-vờ in mai mai-nd e-vờ xins"}
]`;

export class PassageEnrichmentPipeline {
  constructor({ store, liteLLMClient, logger = console }) {
    this.store = store;
    this.liteLLMClient = liteLLMClient;
    this.logger = logger;
  }

  async processPassage({ passageId }) {
    const passage = await this.store.getPassage({ passageId });
    if (!passage) {
      return { success: false, error: 'passage_not_found' };
    }

    const segments = await this.store.getSegmentsByPassage({ passageId });
    if (segments.length === 0) {
      return { success: false, error: 'no_segments' };
    }

    try {
      const enrichments = await this.#enrich({ segments });

      if (enrichments.length !== segments.length) {
        this.logger.warn?.('passage_enrichment_length_mismatch', {
          passage_id: passageId,
          segments: segments.length,
          enrichments: enrichments.length
        });
      }

      // Update each segment (pair by index order)
      let updatedCount = 0;
      for (let i = 0; i < segments.length; i++) {
        const segment = segments[i];
        const enrichment = enrichments[i] ?? {};
        await this.store.updateSegmentEnrichment({
          segmentId: segment.id,
          ipa_text: typeof enrichment.ipa === 'string' && enrichment.ipa.trim() ? enrichment.ipa.trim() : null,
          translation_text: typeof enrichment.translation === 'string' && enrichment.translation.trim() ? enrichment.translation.trim() : null,
          translation_language: 'vi',
          viet_reading_text: typeof enrichment.viet_reading === 'string' && enrichment.viet_reading.trim() ? enrichment.viet_reading.trim() : null
        });
        updatedCount++;
      }

      await this.store.updatePassageEnrichmentStatus({ passageId, enrichmentStatus: 'enriched' });

      this.logger.info?.('passage_enrichment_completed', {
        passage_id: passageId,
        segment_count: updatedCount
      });

      return { success: true, segment_count: updatedCount };
    } catch (error) {
      this.logger.error?.('passage_enrichment_failed', {
        passage_id: passageId,
        error
      });
      return { success: false, error: `${error}` };
    }
  }

  async #enrich({ segments }) {
    const segmentTexts = segments.map((s, i) => `${i + 1}. ${s.text}`).join('\n\n');
    const userPrompt = `Produce IPA transcription, Vietnamese translation, and Vietnamese phonetic reading (viet_reading) for each of the following ${segments.length} English segment(s):\n\n${segmentTexts}\n\nReturn a JSON array with ${segments.length} objects, one per segment, each with "ipa", "translation", and "viet_reading" fields.`;

    const response = await this.liteLLMClient.chatCompletion({
      messages: [
        { role: 'system', content: ENRICHMENT_SYSTEM_PROMPT },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.2,
      response_format: { type: 'json_object' }
    });

    const content = response?.choices?.[0]?.message?.content;
    if (!content) {
      throw new Error('Empty LLM response for enrichment');
    }

    const parsed = JSON.parse(content);
    // Accept both direct array or { enrichments: [...] } / { segments: [...] }
    const rawItems = Array.isArray(parsed)
      ? parsed
      : (parsed.enrichments ?? parsed.segments ?? parsed.items ?? []);

    return rawItems.map((item) => {
      if (!item || typeof item !== 'object') return {};
      return {
        ipa: item.ipa ?? null,
        translation: item.translation ?? null,
        viet_reading: item.viet_reading ?? null
      };
    });
  }
}
