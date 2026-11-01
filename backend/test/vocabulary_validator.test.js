import assert from 'node:assert/strict';
import test from 'node:test';

import { validateVocabularyItem } from '../src/vocabulary_validator.js';

test('accepts English item with IPA', () => {
  assert.deepEqual(validateVocabularyItem(wordInput()), { ok: true });
});

test('rejects English item without IPA', () => {
  assert.deepEqual(validateVocabularyItem(wordInput({ ipa: '' })), { ok: false, reason: 'missing_ipa' });
});

test('accepts Chinese item with pinyin and no IPA', () => {
  assert.deepEqual(
    validateVocabularyItem(
      wordInput({
        language: 'zh',
        term: '资格',
        ipa: '',
        vietnamese_pronunciation: 'zi ge',
        difficulty: 'HSK2',
        example: '我有这个资格。'
      })
    ),
    { ok: true }
  );
});

test('accepts tone-marked pinyin that has no ASCII letter', () => {
  assert.deepEqual(
    validateVocabularyItem(
      wordInput({
        language: 'zh',
        term: '啊',
        ipa: '',
        vietnamese_pronunciation: 'ā',
        difficulty: 'HSK3',
        example: '啊，我明白了。'
      })
    ),
    { ok: true }
  );
});

test('rejects Chinese item without pinyin even when IPA is present', () => {
  assert.deepEqual(
    validateVocabularyItem(
      wordInput({
        language: 'zh',
        term: '技能',
        ipa: '/ignored/',
        vietnamese_pronunciation: '1234',
        difficulty: 'HSK2',
        example: '这个技能很重要。'
      })
    ),
    { ok: false, reason: 'invalid_chinese_pinyin' }
  );
});

test('accepts article suggestions with explicit classification and suggestion type', () => {
  assert.deepEqual(
    validateVocabularyItem(
      wordInput({
        term: 'share knowledge',
        example: 'Teams share knowledge across functions.',
        classification: 'article_phrase',
        suggestion_type: 'phrase',
        difficulty: 'A1',
        level: 'A1'
      }),
      { requireSuggestionMetadata: true }
    ),
    { ok: true }
  );
});

function wordInput(overrides = {}) {
  return {
    term: 'reliable',
    language: 'en',
    meaning_vi: 'dang tin cay',
    part_of_speech: 'adjective',
    ipa: '/rɪˈlaɪəbl/',
    vietnamese_pronunciation: 'ri-lai-uh-bol',
    example: 'She is a reliable teammate.',
    example_vi: 'Co ay la mot dong doi dang tin cay.',
    difficulty: 'B1',
    topics: ['work'],
    ...overrides
  };
}

test('Chinese pronunciation must be pinyin: a Hán-Việt reading is rejected, tone-marked pinyin accepted', () => {
  const base = {
    term: '守墓',
    language: 'zh',
    meaning_vi: 'trông coi phần mộ',
    ipa: '',
    example: '自此，王茂贵就成了守墓人。',
    example_vi: 'Từ đó, ông Vương Mậu Quý trở thành người trông mộ.',
    difficulty: 'HSK5',
    topics: ['article-ingestion']
  };
  assert.deepEqual(validateVocabularyItem({ ...base, vietnamese_pronunciation: 'shǒu mù' }), { ok: true });
  assert.deepEqual(validateVocabularyItem({ ...base, vietnamese_pronunciation: 'yī huìr' }), { ok: true });
  assert.equal(validateVocabularyItem({ ...base, vietnamese_pronunciation: 'thủ mộ' }).reason, 'invalid_chinese_pinyin');
  assert.equal(validateVocabularyItem({ ...base, vietnamese_pronunciation: 'cửu tuần' }).reason, 'invalid_chinese_pinyin');
  assert.equal(validateVocabularyItem({ ...base, vietnamese_pronunciation: '守墓' }).reason, 'invalid_chinese_pinyin');
});
