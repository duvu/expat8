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
  resolveScaleForLanguage
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
  assert.deepEqual(getFallbackDifficultyLevels('HSK3', { language: 'zh' }).slice(0, 4), ['HSK3', 'HSK4', 'HSK2', 'HSK1']);
  assert.equal(getLevelIndex('B2', { language: 'en' }), 3);
  assert.equal(getLevelIndex('HSK5', { language: 'zh' }), 4);
});
