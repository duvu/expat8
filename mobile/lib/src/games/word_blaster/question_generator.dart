import 'dart:math';

import '../../models/vocabulary_word.dart';
import 'word_blaster_mode.dart';
import 'word_pool.dart';

/// One prompt and the labels that will fly on the meteors.
class WordBlasterQuestion {
  const WordBlasterQuestion({
    required this.word,
    required this.mode,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.promptHint,
    this.audioText,
  });

  final VocabularyWord word;
  final WordBlasterMode mode;

  /// Main prompt text (meaning, term, gapped sentence; empty for listening).
  final String prompt;

  /// Secondary line (IPA/pinyin or translation), if any.
  final String? promptHint;

  /// Text to speak for listening mode.
  final String? audioText;

  /// Answer labels; exactly one is correct.
  final List<String> options;
  final int correctIndex;

  String get answer => options[correctIndex];
}

/// Generates questions from a [WordPool]. Deterministic for a given [Random].
class QuestionGenerator {
  QuestionGenerator({
    required this.pool,
    required this.mode,
    required Random random,
  })  : _random = random,
        _queue = List.of(pool.roundWords);

  final WordPool pool;
  final WordBlasterMode mode;
  final Random _random;
  final List<VocabularyWord> _queue;
  final List<VocabularyWord> _retry = [];
  VocabularyWord? _last;

  /// Words answered wrong come back sooner (after at least 3 other prompts).
  void requeue(VocabularyWord word) {
    if (!_retry.contains(word)) _retry.add(word);
  }

  /// Distractor count by wave (2 → 3 → 4), before adaptive adjustments.
  static int distractorsForWave(int wave) =>
      wave <= 2 ? 2 : (wave <= 6 ? 3 : 4);

  WordBlasterQuestion next({required int distractors}) {
    for (var attempt = 0; attempt < pool.roundWords.length * 2 + 2; attempt++) {
      final word = _nextWord();
      final question = _build(word, distractors);
      if (question != null) {
        _last = word;
        return question;
      }
    }
    // Fill the gap may reject every word without a usable example; fall back
    // to a classic-style question so the round never stalls.
    final word = _nextWord();
    _last = word;
    return _build(word, distractors, forceMode: WordBlasterMode.classic)!;
  }

  VocabularyWord _nextWord() {
    if (_retry.isNotEmpty && _random.nextDouble() < 0.35) {
      final candidate = _retry.first;
      if (candidate != _last) {
        _retry.removeAt(0);
        return candidate;
      }
    }
    if (_queue.isEmpty) {
      _queue
        ..addAll(pool.roundWords)
        ..shuffle(_random);
    }
    var word = _queue.removeAt(0);
    if (word == _last && _queue.isNotEmpty) {
      _queue.add(word);
      word = _queue.removeAt(0);
    }
    return word;
  }

  WordBlasterQuestion? _build(
    VocabularyWord word,
    int distractorCount, {
    WordBlasterMode? forceMode,
  }) {
    final effectiveMode = forceMode ?? mode;
    final meaningsAsAnswers = effectiveMode.answersAreMeanings;
    String label(VocabularyWord w) =>
        meaningsAsAnswers ? w.meaningVi.trim() : w.term.trim();

    String prompt;
    String? hint;
    String? audio;
    switch (effectiveMode) {
      case WordBlasterMode.classic:
      case WordBlasterMode.timeAttack:
        prompt = word.meaningVi.trim();
        hint = word.partOfSpeech;
      case WordBlasterMode.reverse:
        prompt = word.term.trim();
        hint = _pronunciation(word);
      case WordBlasterMode.listening:
        prompt = '';
        audio = word.term.trim();
        hint = word.partOfSpeech;
      case WordBlasterMode.fillGap:
        final gapped = gappedSentence(word);
        if (gapped == null) return null;
        prompt = gapped;
        hint = word.exampleVi.trim().isEmpty ? null : word.exampleVi.trim();
    }

    final distractors = pickDistractors(
      word: word,
      candidates: pool.allWords,
      count: distractorCount,
      random: _random,
      meaningsAsAnswers: meaningsAsAnswers,
    );
    final options = [label(word), ...distractors.map(label)];
    final correct = options.first;
    options.shuffle(_random);
    return WordBlasterQuestion(
      word: word,
      mode: effectiveMode,
      prompt: prompt,
      promptHint: hint,
      audioText: audio,
      options: options,
      correctIndex: options.indexOf(correct),
    );
  }

  static String? _pronunciation(VocabularyWord w) {
    if (w.language.startsWith('zh')) {
      final pinyin = w.vietnamesePronunciation.trim();
      return pinyin.isEmpty ? null : pinyin;
    }
    final ipa = w.ipa.trim();
    return ipa.isEmpty ? null : ipa;
  }
}

/// The example sentence with the target blanked, or null if it cannot be
/// blanked (target missing from the example).
String? gappedSentence(VocabularyWord word) {
  final target = (word.blankWord ?? word.term).trim();
  final example = word.example.trim();
  if (target.isEmpty || example.isEmpty) return null;
  final index = example.toLowerCase().indexOf(target.toLowerCase());
  if (index < 0) return null;
  return '${example.substring(0, index)}____${example.substring(index + target.length)}';
}

/// Chooses plausible but never-correct distractors: same part of speech and
/// similar level first, then close spelling or shared topic; words whose
/// meaning overlaps the answer's are excluded.
List<VocabularyWord> pickDistractors({
  required VocabularyWord word,
  required List<VocabularyWord> candidates,
  required int count,
  required Random random,
  bool meaningsAsAnswers = false,
}) {
  final answerMeaning = normalizeMeaning(word.meaningVi);
  final answerTerm = word.term.trim().toLowerCase();
  final level = levelIndexOf(word.difficulty);
  final usedLabels = <String>{meaningsAsAnswers ? answerMeaning : answerTerm};

  final scored = <(double, VocabularyWord)>[];
  for (final c in candidates) {
    final term = c.term.trim().toLowerCase();
    if (term.isEmpty || term == answerTerm) continue;
    final meaning = normalizeMeaning(c.meaningVi);
    if (meaning.isEmpty || meaningsOverlap(meaning, answerMeaning)) continue;
    var score = random.nextDouble() * 1.5;
    if (c.partOfSpeech != null && c.partOfSpeech == word.partOfSpeech) {
      score += 3;
    }
    if ((levelIndexOf(c.difficulty) - level).abs() <= 1) score += 2;
    if (editDistance(term, answerTerm, cap: 4) <= 3) score += 2;
    if (c.topics.any(word.topics.contains)) score += 1;
    scored.add((score, c));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));

  final result = <VocabularyWord>[];
  for (final (_, c) in scored) {
    if (result.length >= count) break;
    final label = meaningsAsAnswers
        ? normalizeMeaning(c.meaningVi)
        : c.term.trim().toLowerCase();
    if (usedLabels.contains(label)) continue;
    usedLabels.add(label);
    result.add(c);
  }
  return result;
}

bool meaningsOverlap(String a, String b) {
  if (a == b) return true;
  final shorter = a.length <= b.length ? a : b;
  final longer = identical(shorter, a) ? b : a;
  if (shorter.length < 3) return false;
  // Whole-phrase containment ("tin cậy" vs "đáng tin cậy").
  return (' $longer ').contains(' $shorter ') ||
      longer.split(RegExp(r'[,;/]')).map((p) => p.trim()).contains(shorter);
}

/// Lowercase, trimmed, Vietnamese diacritics removed, punctuation collapsed.
String normalizeMeaning(String value) {
  final lower = value.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_diacritics[ch] ?? ch);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[()\[\].!?"“”]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int editDistance(String a, String b, {int cap = 1 << 30}) {
  if ((a.length - b.length).abs() > cap) return cap + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      rowMin = min(rowMin, cur[j]);
    }
    if (rowMin > cap) return cap + 1;
    prev = cur;
  }
  return prev[b.length];
}

final Map<String, String> _diacritics = () {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  return {
    for (final entry in groups.entries)
      for (final ch in entry.value.split('')) ch: entry.key,
  };
}();
