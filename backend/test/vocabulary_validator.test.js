import assert from 'node:assert/strict';
import test from 'node:test';

import { validateVocabularyItem } from '../src/vocabulary_validator.js';

test('accepts English item with IPA', () => {
  assert.deepEqual(validateVocabularyItem(wordInput()), { ok: true });
});

test('rejects English item without IPA', () => {
  assert.deepEqual(
    validateVocabularyItem(wordInput({ ipa: '' })),
    { ok: false, reason: 'missing_ipa' }
  );
});

test('accepts Chinese item with pinyin and no IPA', () => {
  assert.deepEqual(
    validateVocabularyItem(wordInput({
      language: 'zh',
      term: '资格',
      ipa: '',
      vietnamese_pronunciation: 'zi ge',
      difficulty: 'HSK2',
      example: '我有这个资格。'
    })),
    { ok: true }
  );
});

test('rejects Chinese item without pinyin even when IPA is present', () => {
  assert.deepEqual(
    validateVocabularyItem(wordInput({
      language: 'zh',
      term: '技能',
      ipa: '/ignored/',
      vietnamese_pronunciation: '1234',
      difficulty: 'HSK2',
      example: '这个技能很重要。'
    })),
    { ok: false, reason: 'invalid_chinese_pinyin' }
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
