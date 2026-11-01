import 'dart:math';

import '../quiz/quiz_core.dart';
import 'math_secondary.dart';
import 'math_skills_map.dart';

/// An integer as shown to players (typographic minus for negatives).
String formatInt(int v) => v < 0 ? '−${-v}' : '$v';

/// School-grade difficulty ladder shared by every math game.
enum MathLevel implements QuizLevel {
  grade1(label: 'Grade 1', summary: '+ and − within 20', targetSeconds: 4),
  grade2(label: 'Grade 2', summary: '+ and − within 100', targetSeconds: 5),
  grade3(label: 'Grade 3', summary: 'Times tables, ÷ facts', targetSeconds: 4),
  grade4(
      label: 'Grade 4',
      summary: '2-digit × 1-digit, ÷, within 1000',
      targetSeconds: 7),
  grade5(
      label: 'Grade 5',
      summary: '2-digit × 2-digit, order of operations',
      targetSeconds: 9),
  grade6(
      label: 'Grade 6',
      summary: 'Brackets, fractions & % of amounts, GCD and LCM',
      targetSeconds: 9),
  grade7(
      label: 'Grade 7',
      summary: 'Negative numbers, one-step equations, ratio, % change',
      targetSeconds: 9),
  grade8(
      label: 'Grade 8',
      summary: 'Powers & roots, two-step equations, substitution, Pythagoras',
      targetSeconds: 10),
  grade9(
      label: 'Grade 9',
      summary: 'Quadratics, simultaneous equations, index laws, functions',
      targetSeconds: 12);

  const MathLevel({
    required this.label,
    required this.summary,
    required this.targetSeconds,
  });

  @override
  String get id => name;

  @override
  final String label;
  @override
  final String summary;

  /// A correct answer faster than this counts as fluent and raises difficulty.
  @override
  final int targetSeconds;

  static MathLevel fromName(String? name) => MathLevel.values
      .firstWhere((l) => l.name == name, orElse: () => MathLevel.grade1);
}

enum MathOp { add, subtract, multiply, divide, mixed }

/// One question. [key] identifies the fact (e.g. `7×8`, commutative forms
/// share a key) so missed facts can be replayed; [hint] is a mental-math
/// strategy shown after a miss.
class MathProblem implements QuizItem {
  const MathProblem({
    required this.text,
    required this.answer,
    required this.op,
    required this.key,
    this.hint,
    this.skillId,
    this.signed = false,
    String? cue,
  }) : _cue = cue;

  factory MathProblem.fromJson(Map<String, dynamic> json) => MathProblem(
        text: json['text'] as String,
        answer: (json['answer'] as num).toInt(),
        op: MathOp.values.firstWhere((o) => o.name == json['op'],
            orElse: () => MathOp.mixed),
        key: json['key'] as String,
        hint: json['hint'] as String?,
        skillId: json['skill'] as String?,
        signed: json['signed'] as bool? ?? false,
        cue: json['cue'] as String?,
      );

  @override
  final String text;
  final int answer;
  final MathOp op;
  @override
  final String key;
  @override
  final String? hint;
  @override
  final String? skillId;

  /// The answer may be negative (grade 7+): options may be negative too and
  /// always include the sign-flipped answer, the classic mistake.
  final bool signed;

  final String? _cue;

  /// A family label ("Equation") for problems too long to fit a token.
  @override
  String get cue => _cue ?? text;

  @override
  String get answerText => formatInt(answer);

  @override
  Map<String, dynamic> toJson() => {
        'text': text,
        'answer': answer,
        'op': op.name,
        'key': key,
        if (hint != null) 'hint': hint,
        if (skillId != null) 'skill': skillId,
        if (signed) 'signed': true,
        if (_cue != null) 'cue': _cue,
      };

  @override
  String toString() => '$text = $answer';
}

/// Generates problems for a [MathLevel]. [difficulty] (0..1) moves inside the
/// level: fast correct answers raise it, misses lower it, so every child plays
/// at the edge of what they can compute. About a quarter of problems replay
/// facts the child missed before.
class MathProblemGenerator implements QuizSource<MathProblem> {
  MathProblemGenerator({
    required this.level,
    Random? random,
    this.weakFacts,
    this.difficulty = 0.3,
    this.replayShare = 0.25,
  }) : random = random ?? Random();

  final MathLevel level;
  final Random random;
  final WeakItemSource<MathProblem>? weakFacts;
  final double replayShare;
  double difficulty;
  String? _lastKey;

  @override
  MathProblem next() {
    MathProblem? problem;
    if (weakFacts != null && random.nextDouble() < replayShare) {
      problem = weakFacts!.pickWeak(level, random, avoidKey: _lastKey);
    }
    for (var attempt = 0;
        problem == null || problem.key == _lastKey;
        attempt++) {
      problem = _generate();
      if (attempt > 5) break;
    }
    _lastKey = problem.key;
    return problem;
  }

  /// Adapts [difficulty] to how the child just did.
  @override
  void recordResult({required bool correct, required Duration elapsed}) {
    final fast = elapsed.inMilliseconds < level.targetSeconds * 1000;
    difficulty += correct ? (fast ? 0.07 : 0.02) : -0.12;
    difficulty = difficulty.clamp(0.0, 1.0);
  }

  /// [count] answer options: the answer plus close, plausible mistakes
  /// (off by one or ten, neighbouring table row, wrong operation), shuffled.
  @override
  List<String> choicesFor(MathProblem problem, {int count = 4}) => [
        for (final c in plausibleChoices(problem, random, count: count))
          formatInt(c),
      ];

  int _between(int min, int max) =>
      max <= min ? min : min + random.nextInt(max - min + 1);

  int _scaled(int from, int to) => (from + (to - from) * difficulty).round();

  MathProblem _generate() {
    switch (level) {
      case MathLevel.grade1:
        final max = _scaled(10, 20);
        return random.nextBool()
            ? _add(max, maxOperand: max - 1)
            : _subtract(max);
      case MathLevel.grade2:
        final max = _scaled(20, 100);
        return random.nextBool()
            ? _add(max, maxOperand: max - 1)
            : _subtract(max);
      case MathLevel.grade3:
        final roll = random.nextDouble();
        final table = _scaled(5, 9);
        if (roll < 0.45) return _times(_between(2, table), _between(2, 9));
        if (roll < 0.8) return _divideFact(_between(2, table), _between(2, 9));
        return random.nextBool()
            ? _add(_scaled(60, 200), maxOperand: _scaled(60, 200) - 1)
            : _subtract(_scaled(60, 200));
      case MathLevel.grade4:
        final roll = random.nextDouble();
        if (roll < 0.4) {
          return _times(_between(11, _scaled(25, 99)), _between(2, 9));
        }
        if (roll < 0.7) {
          return _divideFact(_between(2, 9), _between(2, _scaled(12, 40)));
        }
        final max = _scaled(200, 1000);
        return random.nextBool()
            ? _add(max, maxOperand: max - 1)
            : _subtract(max);
      case MathLevel.grade5:
        final roll = random.nextDouble();
        if (roll < 0.35) {
          return _times(
              _between(11, _scaled(15, 40)), _between(11, _scaled(12, 19)));
        }
        if (roll < 0.6) {
          return _divideFact(
              _between(11, _scaled(12, 25)), _between(2, _scaled(9, 30)));
        }
        if (roll < 0.85) return _orderOfOperations();
        final max = _scaled(1000, 10000);
        return random.nextBool()
            ? _add(max, maxOperand: max - 1)
            : _subtract(max);
      case MathLevel.grade6:
      case MathLevel.grade7:
      case MathLevel.grade8:
      case MathLevel.grade9:
        return secondaryProblem(level, random,
            scaled: _scaled, between: _between);
    }
  }

  MathProblem _add(int limit, {required int maxOperand}) {
    final a = _between(1, max(1, maxOperand - 1));
    final b = _between(1, max(1, limit - a));
    return additionProblem(a, b);
  }

  MathProblem _subtract(int limit) {
    final a = _between(2, limit);
    final b = _between(1, a);
    return subtractionProblem(a, b);
  }

  MathProblem _times(int a, int b) => multiplicationProblem(a, b);

  MathProblem _divideFact(int divisor, int quotient) =>
      divisionProblem(divisor * quotient, divisor);

  MathProblem _orderOfOperations() {
    final b = _between(2, _scaled(5, 9));
    final c = _between(2, 9);
    if (random.nextBool()) {
      final a = _between(1, _scaled(10, 50));
      return MathProblem(
        text: '$a + $b × $c',
        answer: a + b * c,
        op: MathOp.mixed,
        key: '$a+$b×$c',
        skillId: MathSkill.orderOfOperations,
        hint:
            'Multiply first: $b × $c = ${b * c}, then $a + ${b * c} = ${a + b * c}',
      );
    }
    final product = b * c;
    final a = _between(1, product);
    return MathProblem(
      text: '$b × $c − $a',
      answer: product - a,
      op: MathOp.mixed,
      key: '$b×$c−$a',
      skillId: MathSkill.orderOfOperations,
      hint:
          'Multiply first: $b × $c = $product, then $product − $a = ${product - a}',
    );
  }
}

String _sortedKey(int a, String op, int b) => a <= b ? '$a$op$b' : '$b$op$a';

MathProblem additionProblem(int a, int b) {
  final sum = a + b;
  String? hint;
  if (a < 10 && b < 10 && sum > 10) {
    final big = max(a, b), small = min(a, b);
    final toTen = 10 - big;
    hint = 'Make ten: $big + $toTen + ${small - toTen} = $sum';
  } else if (a >= 10 && b >= 10) {
    final ones = b % 10;
    if (ones >= 7) {
      final up = b + (10 - ones);
      hint = 'Round up: $a + $up − ${up - b} = $sum';
    } else {
      final ta = a - a % 10, tb = b - b % 10;
      hint =
          'Tens then ones: $ta + $tb = ${ta + tb}, ${a % 10} + ${b % 10} = ${a % 10 + b % 10}, total $sum';
    }
  }
  return MathProblem(
    text: '$a + $b',
    answer: sum,
    op: MathOp.add,
    key: _sortedKey(a, '+', b),
    skillId: MathSkill.addSub(sum),
    hint: hint,
  );
}

MathProblem subtractionProblem(int a, int b) {
  final diff = a - b;
  String? hint;
  if (b < 10 && a % 10 < b && a > 10) {
    final down = a % 10;
    hint = 'Back to ten: $a − $down − ${b - down} = $diff';
  } else if (b >= 10 && b % 10 >= 7) {
    final up = b + (10 - b % 10);
    hint = 'Take away $up, give back ${up - b}: $a − $up + ${up - b} = $diff';
  } else if (b >= 10) {
    hint = 'Count up from $b to $a: the gap is $diff';
  }
  return MathProblem(
    text: '$a − $b',
    answer: diff,
    op: MathOp.subtract,
    key: '$a−$b',
    skillId: MathSkill.addSub(a),
    hint: hint,
  );
}

MathProblem multiplicationProblem(int a, int b) {
  final product = a * b;
  String? hint;
  final big = max(a, b), small = min(a, b);
  if (big >= 10 && small >= 10) {
    final ones = small % 10, tens = small - ones;
    hint =
        'Split: $big × $tens = ${big * tens}, $big × $ones = ${big * ones}, total $product';
  } else if (big >= 10) {
    final ones = big % 10, tens = big - ones;
    hint =
        'Split: $tens × $small = ${tens * small}, $ones × $small = ${ones * small}, total $product';
  } else if (small == 9 || big == 9) {
    final other = small == 9 ? big : small;
    hint = 'Nine trick: $other × 10 − $other = $product';
  } else if (small == 5 || big == 5) {
    final other = small == 5 ? big : small;
    hint = 'Five trick: $other × 10 ÷ 2 = $product';
  } else if (small.isEven) {
    hint =
        'Double: $big × ${small ~/ 2} = ${big * small ~/ 2}, doubled is $product';
  } else {
    hint =
        'One more group: $big × ${small - 1} = ${big * (small - 1)}, + $big = $product';
  }
  return MathProblem(
    text: '$a × $b',
    answer: product,
    op: MathOp.multiply,
    key: _sortedKey(a, '×', b),
    skillId: MathSkill.multiply(a, b),
    hint: hint,
  );
}

MathProblem divisionProblem(int dividend, int divisor) {
  final quotient = dividend ~/ divisor;
  return MathProblem(
    text: '$dividend ÷ $divisor',
    answer: quotient,
    op: MathOp.divide,
    key: '$dividend÷$divisor',
    skillId: MathSkill.divide(divisor, quotient),
    hint: 'Think times table: $divisor × $quotient = $dividend',
  );
}

/// Close wrong answers a child would plausibly produce, plus the answer.
List<int> plausibleChoices(MathProblem problem, Random random,
    {int count = 4}) {
  final answer = problem.answer;
  final candidates = <int>[
    answer + 1,
    answer - 1,
    answer + 10,
    answer - 10,
    answer + 2,
    answer - 2,
    if (answer >= 100) _swapLastDigits(answer),
  ];
  final operands = RegExp(r'\d+')
      .allMatches(problem.text)
      .map((m) => int.parse(m.group(0)!))
      .toList();
  if (problem.op == MathOp.multiply && operands.length == 2) {
    candidates.addAll([
      answer + operands[0],
      answer - operands[0],
      answer + operands[1],
      answer - operands[1]
    ]);
  }
  if (problem.op == MathOp.add && operands.length == 2) {
    candidates.add((operands[0] - operands[1]).abs());
  }
  if (problem.op == MathOp.subtract && operands.length == 2) {
    candidates.add(operands[0] + operands[1]);
  }
  candidates.shuffle(random);
  // Keep every option close to the answer so it has to be computed, not
  // guessed from its size.
  final limit = max(6, answer.abs() ~/ 4 + 6);
  final choices = <int>{answer};
  bool allowed(int c) => problem.signed || c >= 0;
  // Signed answers always offer the sign flip, the classic mistake.
  if (problem.signed && answer != 0) choices.add(-answer);
  for (final c in candidates) {
    if (choices.length >= count) break;
    if (allowed(c) && c != answer && (c - answer).abs() <= limit) {
      choices.add(c);
    }
  }
  var spread = 3;
  while (choices.length < count) {
    final c = answer + (random.nextBool() ? 1 : -1) * spread++;
    if (allowed(c)) choices.add(c);
  }
  return choices.toList()..shuffle(random);
}

int _swapLastDigits(int n) {
  final s = n.toString();
  if (s.length < 2) return n;
  return int.parse(
      s.substring(0, s.length - 2) + s[s.length - 1] + s[s.length - 2]);
}
