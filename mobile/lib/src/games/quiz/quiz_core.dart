import 'dart:math';

/// A difficulty step of a subject (e.g. Grade 3 math, Grade 7 English).
abstract interface class QuizLevel {
  /// Stable identifier used for storage keys.
  String get id;
  String get label;
  String get summary;

  /// A correct answer faster than this counts as fluent.
  int get targetSeconds;
}

/// One question of any subject. Games only rely on this interface, so the
/// same game can train math facts or English grammar.
abstract interface class QuizItem {
  /// The full question shown to the player.
  String get text;

  /// A short label for small surfaces (a falling token, a chip).
  String get cue;

  /// The correct answer as it appears on an answer button.
  String get answerText;

  /// Identifies the item across rounds (missed items are replayed by key).
  String get key;

  /// A strategy or rule shown after a miss.
  String? get hint;

  /// The curriculum skill this item trains, or null when the item is not
  /// tied to one (answers to such items are not tracked per skill).
  String? get skillId;

  Map<String, dynamic> toJson();
}

/// Produces items for one level and adapts to how the player is doing.
abstract interface class QuizSource<T extends QuizItem> {
  T next();

  /// [count] distinct answer options including the right one, shuffled.
  List<String> choicesFor(T item, {int count = 4});

  void recordResult({required bool correct, required Duration elapsed});
}

/// Items the player keeps missing, offered back for practice.
abstract interface class WeakItemSource<T extends QuizItem> {
  T? pickWeak(QuizLevel level, Random random, {String? avoidKey});
}
