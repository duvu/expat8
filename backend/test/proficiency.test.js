import assert from 'node:assert/strict';
import test from 'node:test';

import {
  decrementLevel,
  getDefaultProficiencyLevel,
  getFallbackDifficultyLevels,
  getLevelIndex,
  getProficiencyProfile,
  incrementLevel,
  normalizeDifficultyLevel,
  resolveScaleForLanguage,
  selectNewCardsByLevel
} from '../src/proficiency.js';

test('resolves proficiency scale by language', () => {
  assert.equal(resolveScaleForLanguage('en'), 'cefr');
  assert.equal(resolveScaleForLanguage('zh'), 'hsk');
  assert.equal(resolveScaleForLanguage('zh-CN'), 'hsk');
  assert.equal(resolveScaleForLanguage('fr'), 'cefr');
});

test('resolves profile defaults by language', () => {
  assert.equal(getProficiencyProfile({ language: 'en' }).defaultLevel, 'A1');
  assert.equal(getProficiencyProfile({ language: 'zh' }).defaultLevel, 'HSK1');
  assert.equal(getDefaultProficiencyLevel({ language: 'zh' }), 'HSK1');
});

test('normalizes levels per scale profile', () => {
  assert.equal(normalizeDifficultyLevel('b1', { language: 'en' }), 'B1');
  assert.equal(normalizeDifficultyLevel('beginner', { language: 'en' }), 'A1');
  assert.equal(normalizeDifficultyLevel('hsk3', { language: 'zh' }), 'HSK3');
  assert.equal(normalizeDifficultyLevel('B1', { language: 'zh' }), null);
});

test('increments and decrements levels within active scale', () => {
  assert.equal(incrementLevel('A1', { language: 'en' }), 'A2');
  assert.equal(decrementLevel('A1', { language: 'en' }), 'A1');
  assert.equal(incrementLevel('HSK2', { language: 'zh' }), 'HSK3');
  assert.equal(decrementLevel('HSK1', { language: 'zh' }), 'HSK1');
});

test('computes fallback ordering and level index by scale', () => {
  assert.deepEqual(getFallbackDifficultyLevels('B1', { language: 'en' }).slice(0, 4), ['B1', 'B2', 'A2', 'A1']);
  assert.deepEqual(getFallbackDifficultyLevels('HSK3', { language: 'zh' }).slice(0, 4), [
    'HSK3',
    'HSK4',
    'HSK2',
    'HSK1'
  ]);
  assert.equal(getLevelIndex('B2', { language: 'en' }), 3);
  assert.equal(getLevelIndex('HSK5', { language: 'zh' }), 4);
});

test('selectNewCardsByLevel takes 80% at the learner level and 20% from lower levels', () => {
  const words = [];
  for (const [level, count] of [['A1', 30], ['A2', 10], ['B1', 10], ['B2', 10]]) {
    for (let index = 0; index < count; index += 1) {
      words.push({ id: `${level}-${index}`, difficulty: level, created_at: `2026-01-01T00:00:${String(index).padStart(2, '0')}Z` });
    }
  }
  const picked = selectNewCardsByLevel(words, { level: 'B1', language: 'en', count: 10 });
  const byLevel = picked.reduce((acc, word) => ({ ...acc, [word.difficulty]: (acc[word.difficulty] ?? 0) + 1 }), {});
  assert.equal(picked.length, 10);
  assert.equal(byLevel.B1, 8);
  assert.equal((byLevel.A1 ?? 0) + (byLevel.A2 ?? 0), 2);
  assert.equal(byLevel.B2, undefined);
});

test('selectNewCardsByLevel falls back to the nearest levels instead of A1', () => {
  const words = [
    ...Array.from({ length: 20 }, (_, index) => ({ id: `a1-${index}`, difficulty: 'A1', created_at: '2026-01-01' })),
    { id: 'a2', difficulty: 'A2', created_at: '2026-01-01' },
    { id: 'b2', difficulty: 'B2', created_at: '2026-01-01' }
  ];
  const picked = selectNewCardsByLevel(words, { level: 'B1', language: 'en', count: 4 }).map((word) => word.id);
  assert.equal(picked.length, 4);
  assert.ok(picked.includes('a2') && picked.includes('b2'), 'nearest levels are used before distant A1 words');
});

test('selectNewCardsByLevel shuffles instead of returning level runs or always the newest words', () => {
  const words = [];
  for (const level of ['A1', 'A2', 'B1']) {
    for (let index = 0; index < 40; index += 1) {
      words.push({ id: `${level}-${index}`, difficulty: level, created_at: `2026-01-01T00:00:${String(index).padStart(2, '0')}Z` });
    }
  }
  const batches = Array.from({ length: 30 }, () => selectNewCardsByLevel(words, { level: 'B1', language: 'en', count: 10 }));
  const seen = new Set(batches.flat().map((word) => word.id));
  assert.ok(seen.size > 60, 'draws vary across batches');
  for (const batch of batches) {
    assert.equal(batch.filter((word) => word.difficulty === 'B1').length, 8);
    assert.equal(batch.filter((word) => word.difficulty !== 'B1').length, 2);
  }
  const firstPositions = batches.map((batch) => batch.findIndex((word) => word.difficulty !== 'B1'));
  assert.ok(new Set(firstPositions).size > 3, 'lower-level cards land at varied positions');
});

test('selectNewCardsByLevel gives the lowest-level learner only their own level', () => {
  const words = ['A1', 'A2', 'B1'].flatMap((level) =>
    Array.from({ length: 10 }, (_, index) => ({ id: `${level}-${index}`, difficulty: level }))
  );
  const picked = selectNewCardsByLevel(words, { level: 'A1', language: 'en', count: 10 });
  assert.ok(picked.every((word) => word.difficulty === 'A1'));
});
