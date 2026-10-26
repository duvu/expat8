import 'dart:math';

import '../models/study_event.dart';
import '../models/vocabulary_word.dart';

/// Active-recall forms of a review card. A review asks the learner to
/// produce or recognise the word instead of rating a card they just read.
enum ReviewExerciseKind {
  /// See the word, pick its Vietnamese meaning.
  chooseMeaning,

  /// Hear the word, pick its meaning (needs text-to-speech).
  listen,

  /// Example sentence with the word blanked, pick the missing word.
  fillBlank,

  /// See the meaning (and the blanked example), type the word.
  typeWord,
}

class ReviewExercise {
  const ReviewExercise({
    required this.kind,
    required this.word,
    required this.answer,
    this.choices = const [],
    this.blankedExample,
  });

  final ReviewExerciseKind kind;
  final VocabularyWord word;

  /// The correct choice (or the word to type).
  final String answer;

  /// Shuffled options containing [answer]; empty for [ReviewExerciseKind.typeWord].
  final List<String> choices;

  /// The example sentence with the word replaced by `___`, when it has one.
  final String? blankedExample;
}

const _choiceCount = 4;
const _blank = '___';

/// [word]'s example with the word blanked, or null when the sentence does
/// not contain it as a whole word.
String? blankedExample(VocabularyWord word) {
  final pattern = RegExp(
    r'(?<![\p{L}\p{N}])' +
        RegExp.escape(word.term.trim()) +
        r'(?![\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true,
  );
  final example = word.example.trim();
  if (word.term.trim().isEmpty || !pattern.hasMatch(example)) return null;
  return example.replaceFirst(pattern, _blank);
}

/// Picks an exercise for a due review of [word], or null when none fits
/// (the plain card is shown instead). Distractors come from [pool], the
/// learner's other cached words of the same language.
ReviewExercise? buildReviewExercise(
  VocabularyWord word,
  List<VocabularyWord> pool, {
  required Random random,
  bool canListen = false,
}) {
  final others = pool
      .where((w) => w.localId != word.localId && w.language == word.language)
      .toList();
  List<String>? choicesFrom(String answer, String Function(VocabularyWord) of) {
    final distractors = {
      for (final w in others)
        if (of(w).trim().isNotEmpty &&
            of(w).trim().toLowerCase() != answer.trim().toLowerCase())
          of(w).trim(),
    }.toList()
      ..shuffle(random);
    if (distractors.length < _choiceCount - 1) return null;
    return [answer, ...distractors.take(_choiceCount - 1)]..shuffle(random);
  }

  final blanked = blankedExample(word);
  // Typing suits single Latin-script words (not phrases or Chinese characters).
  final isTypeable = word.entryType == 'word' &&
      RegExp(r"^[A-Za-z][A-Za-z'-]{0,13}$").hasMatch(word.term.trim());
  final candidates = <ReviewExercise>[
    if (choicesFrom(word.meaningVi, (w) => w.meaningVi) case final choices?)
      ReviewExercise(
          kind: ReviewExerciseKind.chooseMeaning,
          word: word,
          answer: word.meaningVi,
          choices: choices),
    if (canListen)
      if (choicesFrom(word.meaningVi, (w) => w.meaningVi) case final choices?)
        ReviewExercise(
            kind: ReviewExerciseKind.listen,
            word: word,
            answer: word.meaningVi,
            choices: choices),
    if (blanked != null)
      if (choicesFrom(word.term, (w) => w.term) case final choices?)
        ReviewExercise(
            kind: ReviewExerciseKind.fillBlank,
            word: word,
            answer: word.term,
            choices: choices,
            blankedExample: blanked),
    if (isTypeable)
      ReviewExercise(
          kind: ReviewExerciseKind.typeWord,
          word: word,
          answer: word.term.trim(),
          blankedExample: blanked),
  ];
  return candidates.isEmpty
      ? null
      : candidates[random.nextInt(candidates.length)];
}

/// How a typed answer compares with the word.
enum TypedAnswer { exact, nearMiss, wrong }

/// Case-insensitive; one typo in a word of five letters or more counts as a
/// near miss.
TypedAnswer checkTypedAnswer(String typed, String answer) {
  String norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final a = norm(typed);
  final b = norm(answer);
  if (a == b) return TypedAnswer.exact;
  if (b.length >= 5 && _editDistance(a, b) == 1) return TypedAnswer.nearMiss;
  return TypedAnswer.wrong;
}

int _editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      current[j] = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      ].reduce(min);
    }
    previous = current;
  }
  return previous[b.length];
}

/// Answers slower than this count as recalled with effort.
const slowAnswer = Duration(seconds: 12);

/// The rating an answer earns: wrong = forgotten (`too_hard`, which also
/// feeds the "many wrong answers" level rule); slow or nearly right = `hard`;
/// right = `easy`. Never `too_easy`, which would move the learner up a level.
StudyRating gradeReviewAnswer({
  required bool correct,
  required Duration elapsed,
  bool nearMiss = false,
}) {
  if (!correct) return StudyRating.tooHard;
  if (nearMiss || elapsed > slowAnswer) return StudyRating.hard;
  return StudyRating.easy;
}
