import 'dart:math';

import '../quiz/quiz_core.dart';
import '../quiz/quiz_round.dart';
import '../quiz/quiz_skills.dart';
import 'english_bank.dart';

/// Lower-secondary English grades.
enum EnglishLevel implements QuizLevel {
  grade6(
      label: 'Grade 6',
      summary: 'Present simple & continuous, articles, past simple',
      bank: grade6Bank),
  grade7(
      label: 'Grade 7',
      summary: 'Past continuous, present perfect, comparison, future',
      bank: grade7Bank),
  grade8(
      label: 'Grade 8',
      summary: 'Conditionals 1–2, passive, relative clauses, verb patterns',
      bank: grade8Bank),
  grade9(
      label: 'Grade 9',
      summary: 'Reported speech, conditional 3, wish, word formation',
      bank: grade9Bank);

  const EnglishLevel(
      {required this.label, required this.summary, required this.bank});

  @override
  final String label;
  @override
  final String summary;
  final List<EnglishEntry> bank;

  @override
  String get id => name;

  /// Reading a sentence takes longer than a times-table fact.
  @override
  int get targetSeconds => 8;

  static EnglishLevel fromName(String? name) => EnglishLevel.values
      .firstWhere((l) => l.name == name, orElse: () => EnglishLevel.grade6);
}

/// A fill-in-the-blank sentence.
class EnglishItem implements QuizItem {
  const EnglishItem({
    required this.topic,
    required this.sentence,
    required this.answer,
    required this.distractors,
    this.hint,
  });

  factory EnglishItem.fromEntry(EnglishEntry e) => EnglishItem(
      topic: e.$1, sentence: e.$2, answer: e.$3, distractors: e.$4, hint: e.$5);

  factory EnglishItem.fromJson(Map<String, dynamic> json) => EnglishItem(
        topic: json['topic'] as String,
        sentence: json['text'] as String,
        answer: json['answer'] as String,
        distractors: [for (final d in json['distractors'] as List) d as String],
        hint: json['hint'] as String?,
      );

  static const blank = '___';

  final String topic;
  final String sentence;
  final String answer;
  final List<String> distractors;
  @override
  final String? hint;

  /// English items are not tied to curriculum skills yet.
  @override
  String? get skillId => null;

  @override
  String get text => sentence;

  @override
  String get cue => topic;

  @override
  String get answerText => answer;

  @override
  String get key => sentence;

  /// The finished sentence (blank filled with the answer).
  String get completed => sentence.replaceFirst(blank, answer);

  @override
  Map<String, dynamic> toJson() => {
        'topic': topic,
        'text': sentence,
        'answer': answer,
        'distractors': distractors,
        if (hint != null) 'hint': hint,
      };
}

/// Deals a level's items like a shuffled deck (no repeats until all were
/// seen), replaying missed items about a quarter of the time.
class EnglishSource implements QuizSource<EnglishItem> {
  EnglishSource({
    required this.level,
    Random? random,
    this.weakItems,
    this.replayShare = 0.25,
  }) : random = random ?? Random();

  final EnglishLevel level;
  final Random random;
  final WeakItemSource<EnglishItem>? weakItems;
  final double replayShare;
  final List<EnglishItem> _deck = [];
  String? _lastKey;

  @override
  EnglishItem next() {
    EnglishItem? item;
    if (weakItems != null && random.nextDouble() < replayShare) {
      item = weakItems!.pickWeak(level, random, avoidKey: _lastKey);
    }
    if (item == null) {
      if (_deck.isEmpty) {
        _deck.addAll(level.bank.map(EnglishItem.fromEntry));
        _deck.shuffle(random);
        if (_deck.length > 1 && _deck.last.key == _lastKey) {
          _deck.insert(0, _deck.removeLast());
        }
      }
      item = _deck.removeLast();
    }
    _lastKey = item.key;
    return item;
  }

  @override
  List<String> choicesFor(EnglishItem item, {int count = 4}) {
    final options = [item.answer, ...item.distractors.take(count - 1)];
    return options..shuffle(random);
  }

  /// The bank is curated per grade; nothing to adapt within a level.
  @override
  void recordResult({required bool correct, required Duration elapsed}) {}
}

/// Missed English items and per-grade stats.
class EnglishSkillTracker extends SkillTracker<EnglishItem> {
  EnglishSkillTracker(super.storage)
      : super(
            storageKey: 'games.english.skills.v1',
            decode: EnglishItem.fromJson);
}

/// A round of an English game.
typedef EnglishRoundLog = QuizRoundLog<EnglishItem, EnglishLevel>;
