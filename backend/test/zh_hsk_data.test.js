import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { validateVocabularyItem } from '../src/vocabulary_validator.js';

const dataDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'data', 'zh_hsk');
const minimumCounts = { HSK1: 150, HSK2: 147, HSK3: 298, HSK4: 598, HSK5: 800, HSK6: 800 };
const HAN = /\p{Script=Han}/gu;

async function loadLevels() {
  const levels = {};
  for (const name of (await readdir(dataDir)).filter((file) => file.endsWith('.json')).sort()) {
    levels[name.replace('.json', '').toUpperCase()] = JSON.parse(await readFile(path.join(dataDir, name), 'utf8'));
  }
  return levels;
}

test('zh HSK data: one file per level, each at least the verified size', async () => {
  const levels = await loadLevels();
  assert.deepEqual(Object.keys(levels), Object.keys(minimumCounts));
  for (const [level, minimum] of Object.entries(minimumCounts)) {
    assert.ok(levels[level].length >= minimum, `${level} has ${levels[level].length}, expected >= ${minimum}`);
  }
});

test('zh HSK data: every word passes validateVocabularyItem and matches its file', async () => {
  for (const [level, words] of Object.entries(await loadLevels())) {
    for (const word of words) {
      assert.deepEqual(validateVocabularyItem(word), { ok: true }, `${level} ${word.term}`);
      assert.equal(word.language, 'zh');
      assert.equal(word.difficulty, level, `${word.term} is in the wrong file`);
      assert.equal(word.ipa, '');
      assert.ok(['word', 'phrase'].includes(word.entry_type), `${word.term} entry_type`);
      assert.ok(word.topics.length >= 1 && word.topics.length <= 3, `${word.term} topics`);
      assert.ok(word.example.includes(word.term), `${word.term} missing from its example`);
      assert.doesNotMatch(word.vietnamese_pronunciation, /[0-9]/, `${word.term} pinyin has digits`);
      assert.match(word.vietnamese_pronunciation, /^[\p{Ll}̀-ͯ ]+$/u, `${word.term} pinyin shape`);
      assert.equal(word.example.replace(HAN, '').replace(/[，。？！、：；“”（）…]/gu, ''), '', `${word.term} example`);
      assert.doesNotMatch(`${word.meaning_vi}${word.example_vi}`, HAN, `${word.term} Chinese in Vietnamese text`);
    }
  }
});

test('zh HSK data: no term appears twice, within or across levels', async () => {
  const seen = new Map();
  for (const [level, words] of Object.entries(await loadLevels())) {
    for (const word of words) {
      assert.ok(!seen.has(word.term), `${word.term} is in both ${seen.get(word.term)} and ${level}`);
      seen.set(word.term, level);
    }
  }
});
