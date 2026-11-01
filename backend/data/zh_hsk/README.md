# Chinese (zh) HSK 2.0 vocabulary pool

`hsk1.json` ... `hsk6.json`: arrays of words in the API/seed shape (`term`, `language: "zh"`, `meaning_vi`,
`part_of_speech`, `ipa: ""`, `vietnamese_pronunciation` = pinyin with tone marks, `example`, `example_vi`,
`difficulty: "HSK1".."HSK6"`, `topics`, `entry_type`, optional `explanation`). Simplified characters only.

Import (idempotent; an existing `(language, normalized_term)` is never modified):

```bash
cd backend
npm run import:words -- --dir data/zh_hsk --dry-run   # validates only, writes nothing
DATABASE_URL=... npm run import:words -- --dir data/zh_hsk
```

## Counts

| Level | Words | Note |
| --- | --- | --- |
| HSK1 | 150 | complete official list |
| HSK2 | 147 | official 150 minus 3 words that the source already lists in HSK1 (lower level wins) |
| HSK3 | 298 | official 300 minus 2 overlap words |
| HSK4 | 598 | official 600 minus 2 overlap words |
| HSK5 | 800 | the 800 most frequent of the 1,298 words that are new in HSK5 |
| HSK6 | 800 | the 800 most frequent of the 2,500 words that are new in HSK6 |
| Total | 2,793 | no duplicate term across levels |

The shortfall in HSK2-4 is not missing data: a word listed in two official levels keeps its lower level.

## Source and licence of the level assignment

Level membership (word -> HSK 2.0 level) and a cross-check pinyin come from
<https://github.com/drkameleon/complete-hsk-vocabulary> (`complete.json`, tags `old-1`..`old-6`), MIT licence,
which itself builds on clem109/hsk-vocabulary (old lists) and CC-CEDICT for definitions. Only the word -> level
assignment (and its pinyin readings as a cross-check) was taken. Vietnamese meanings, examples, notes and topics
were written for this project; no English gloss or CC-CEDICT text is copied. HSK5/HSK6 are not the full official
lists: pure proper-noun entries are skipped, the rest ranked by the source's frequency rank, top 800 kept.

## Method

1. Selection: lowest `old-N` tag per word, HSK5/6 cut by frequency (above).
2. Writing: batches of about 100 words were written against a fixed brief (closed topic list, closed part-of-speech
   list, citation-tone pinyin, one example per word that contains the term verbatim, length limits per level, no
   digits/Latin letters in examples, Hán Việt only when certain). The writer saw all dictionary readings of the word
   and had to choose the reading matching the HSK sense.
3. Independent review: a second pass over every batch checked pinyin/sense, meaning, example naturalness and
   vocabulary level, translation, notes and Hán Việt; 148 entries were corrected (mostly examples rewritten with
   easier words, a few wrong or doubtful notes fixed or removed, one wrong gloss).
4. Tool checks (below) and a hand read of random samples.

Conventions: pinyin uses one space per syllable, citation tones (no 一/不/third-tone sandhi: `bù shì`, `yī qǐ`),
neutral tone unmarked (`xiè xie`), erhua glued (`yī huìr`), `ü` kept. `entry_type: "phrase"` only for set phrases.
The pinyin reading is for the HSK sense; other readings of polyphones are sometimes mentioned in `explanation`.

## QA report

- Structure: all 2,793 entries pass `validateVocabularyItem`, no duplicate terms, difficulty equals the file level,
  topics are 1-3 tags from the closed list, examples contain only Chinese characters and full-width punctuation,
  Han-character length per level HSK1 5-14, HSK2 6-16, HSK3 8-20, HSK4 9-22, HSK5 10-26, HSK6 10-28; no
  traditional characters (OpenCC t2s leaves every example and term unchanged). `test/zh_hsk_data.test.js` enforces this.
- Pinyin vs pypinyin 0.55 (`Style.TONE`, heteronym sets): 2,793 checked, 151 differences before and after review.
  142 are neutral-tone only (our unmarked syllable vs pypinyin's marked one, e.g. `mā ma` vs `mā mā`); 6 polyphones
  (谁 shéi/shuí, 长 cháng, 地 de, 弹 tán, 露 lòu, 幢 zhuàng: pypinyin is wrong or the reading depends on the sense);
  3 other (一会儿 erhua notation, 大夫 dài fu where pypinyin gives dà fū, 嗯 èn). Another 30 entries differ from
  pypinyin by a marked tone: 一/不 sandhi, or a deliberate sense-based reading (e.g. 脏 zāng, 颇 pō, 照片 zhào piàn,
  电子 diàn zǐ, 肚子 dù zi). Each was reviewed by hand; the only real fix was the erhua notation of 一会儿. All
  readings except 5 (neutral-tone variants, `lüè` vs the source's `lu:è`, erhua) are among the source's readings.
- Level of the example vocabulary (HSK1-3): characters outside the words of that level or lower were flagged in
  83 examples before review; 81 were rewritten, 2 remain by necessity (自行车 uses the measure word 辆, 刮 needs 风).
- Hand read: about 50 (HSK1), 42 (HSK2), 40 (HSK3), 40 (HSK4), 42 (HSK5), 42 (HSK6) random entries; issues found
  (an illogical HSK1 example, repeated frames, the word "Collocation" left in 7 Vietnamese notes) were fixed.

## Known limits

- Not verified by a native human reviewer; Hán Việt notes are only present when the writers were certain, and
  doubtful ones were removed in review. Spot-check before using as exam material.
- HSK5/HSK6 are partial (top 800 by frequency); the long tail of the official lists is not included.
- The dry run validates but cannot tell "already present" from "new" (it never touches the database).
