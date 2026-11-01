import 'dart:math';

import 'math_problem.dart';
import 'math_skills_map.dart';

// Lower-secondary problem families (grades 6-9). Every answer is an integer;
// from grade 7 answers may be negative ([MathProblem.signed]). Each builder
// returns the problem with a worked-strategy hint.

const _sup = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹'
};

String _power(int n) => n.toString().split('').map((d) => _sup[d]!).join();

/// An integer as written in a problem: −7 (leading) or (−7) after an operator.
String signed(int v, {bool leading = false}) =>
    v >= 0 ? '$v' : (leading ? '−${-v}' : '(−${-v})');

/// [v] with its sign as an added/subtracted term: "+ 5" or "− 5".
String _term(int v) => v >= 0 ? '+ $v' : '− ${-v}';

/// "3x", "x", "−x", "−4x".
String _coefficient(int a, String variable) => switch (a) {
      1 => variable,
      -1 => '−$variable',
      _ => '${signed(a, leading: true)}$variable',
    };

int _gcd(int a, int b) => b == 0 ? a.abs() : _gcd(b, a % b);

MathProblem _p(String skillId, String text, int answer, String hint,
        {bool signed = false, String? cue}) =>
    MathProblem(
      text: text,
      answer: answer,
      op: MathOp.mixed,
      key: text,
      hint: hint,
      skillId: skillId,
      signed: signed,
      cue: cue,
    );

// ─── grade 6 ────────────────────────────────────────────────────────────────

MathProblem bracketsProblem(int a, int b, int c) {
  final sum = a + b;
  return _p(MathSkill.brackets, '($a + $b) × $c', sum * c,
      'Brackets first: $a + $b = $sum, then $sum × $c = ${sum * c}');
}

MathProblem fractionOfProblem(int numerator, int denominator, int whole) {
  final part = whole ~/ denominator;
  return _p(
      MathSkill.fractionOfAmount,
      '$numerator/$denominator of $whole',
      part * numerator,
      '$whole ÷ $denominator = $part, then × $numerator = ${part * numerator}');
}

MathProblem percentOfProblem(int percent, int base) {
  final answer = base * percent ~/ 100;
  final hint = switch (percent) {
    50 => 'Half of $base = $answer',
    25 => 'A quarter: $base ÷ 4 = $answer',
    75 => 'Three quarters: $base ÷ 4 = ${base ~/ 4}, × 3 = $answer',
    _ => '10% of $base = ${base ~/ 10}, × ${percent ~/ 10} = $answer',
  };
  return _p(MathSkill.percentOfAmount, '$percent% of $base', answer, hint);
}

MathProblem gcdProblem(int a, int b) {
  final g = _gcd(a, b);
  return _p(MathSkill.gcd, 'GCD($a, $b)', g,
      'Largest number dividing both: $a = $g × ${a ~/ g}, $b = $g × ${b ~/ g}');
}

MathProblem lcmProblem(int a, int b) {
  final l = a * b ~/ _gcd(a, b);
  return _p(MathSkill.lcm, 'LCM($a, $b)', l,
      'Smallest common multiple: $a × $b ÷ GCD ${_gcd(a, b)} = $l');
}

// ─── grade 7 ────────────────────────────────────────────────────────────────

MathProblem integerProblem(int a, String op, int b) {
  final answer = switch (op) {
    '+' => a + b,
    '−' => a - b,
    '×' => a * b,
    _ => a ~/ b,
  };
  final hint = switch (op) {
    '+' when (a < 0) == (b < 0) =>
      'Same signs: add ${a.abs()} + ${b.abs()} and keep the sign',
    '+' =>
      'Different signs: subtract the sizes and take the sign of the bigger one',
    '−' =>
      'Subtracting is adding the opposite: ${signed(a, leading: true)} + ${signed(-b)} = ${signed(answer, leading: true)}',
    _ => (a < 0) == (b < 0)
        ? 'Same signs give a positive result'
        : 'Different signs give a negative result',
  };
  return _p(MathSkill.integerOperations,
      '${signed(a, leading: true)} $op ${signed(b)}', answer, hint,
      signed: true);
}

MathProblem oneStepEquation(int x, String op, int k) {
  final (text, hint) = switch (op) {
    '+' => ('x + $k = ${x + k}', 'Undo + $k: ${x + k} − $k = $x'),
    '−' => (
        'x − $k = ${x - k}',
        'Undo − $k: ${signed(x - k, leading: true)} + $k = $x'
      ),
    '×' => (
        '${k}x = ${k * x}',
        'Undo × $k: ${signed(k * x, leading: true)} ÷ $k = $x'
      ),
    _ => ('x ÷ $k = $x', 'Undo ÷ $k: $x × $k = ${x * k}'),
  };
  // For "x ÷ k = q" the unknown is q × k.
  final answer = op == '÷' ? x * k : x;
  return _p(MathSkill.oneStepEquations, '$text, x = ?', answer, hint,
      signed: true, cue: 'Equation');
}

MathProblem ratioProblem(int total, int p, int q) {
  final unit = total ~/ (p + q);
  final larger = max(p, q) * unit;
  return _p(
      MathSkill.ratioShare,
      'Share $total in ratio $p:$q. Larger part?',
      larger,
      '$total ÷ ${p + q} parts = $unit, larger share ${max(p, q)} × $unit = $larger',
      cue: 'Ratio');
}

MathProblem percentChangeProblem(int base, int percent,
    {required bool increase}) {
  final change = base * percent ~/ 100;
  final answer = increase ? base + change : base - change;
  return _p(
      MathSkill.percentChange,
      '${increase ? 'Increase' : 'Decrease'} $base by $percent%',
      answer,
      '$percent% of $base = $change, $base ${increase ? '+' : '−'} $change = $answer',
      cue: '% change');
}

// ─── grade 8 ────────────────────────────────────────────────────────────────

MathProblem powerProblem(int base, int exponent) {
  final answer = pow(base, exponent).toInt();
  return _p(MathSkill.integerPowers, '$base${_power(exponent)}', answer,
      '${List.filled(exponent, base).join(' × ')} = $answer');
}

MathProblem rootProblem(int root, {bool cube = false}) => cube
    ? _p(MathSkill.roots, '∛${root * root * root}', root,
        '$root × $root × $root = ${root * root * root}')
    : _p(MathSkill.roots, '√${root * root}', root,
        '$root × $root = ${root * root}');

MathProblem twoStepEquation(int a, int b, int x) {
  final c = a * x + b;
  return _p(
      MathSkill.twoStepEquations,
      '${a}x ${_term(b)} = ${signed(c, leading: true)}, x = ?',
      x,
      'Undo ${_term(b)} first: ${signed(c, leading: true)} ${_term(-b)} = ${signed(a * x, leading: true)}, then ÷ $a = $x',
      signed: true,
      cue: 'Equation');
}

MathProblem substitutionProblem(int p, int q, int a, int b) {
  final answer = p * a + q * b;
  return _p(
      MathSkill.substitution,
      '${p}a + ${q}b when a = ${signed(a, leading: true)}, b = ${signed(b, leading: true)}',
      answer,
      '$p × ${signed(a)} + $q × ${signed(b)} = ${signed(p * a, leading: true)} ${_term(q * b)} = ${signed(answer, leading: true)}',
      signed: true,
      cue: 'Substitute');
}

MathProblem pythagorasProblem(int a, int b) {
  final c = sqrt(a * a + b * b).round();
  return _p(MathSkill.pythagoras, 'Legs $a and $b: hypotenuse?', c,
      '√($a² + $b²) = √${a * a + b * b} = $c',
      cue: 'Pythagoras');
}

// ─── grade 9 ────────────────────────────────────────────────────────────────

MathProblem quadraticProblem(int r1, int r2) {
  final b = -(r1 + r2), c = r1 * r2;
  final terms = [
    'x²',
    if (b != 0) '${b > 0 ? '+' : '−'} ${_coefficient(b.abs(), 'x')}',
    if (c != 0) _term(c)
  ];
  final larger = max(r1, r2);
  String factor(int r) => r >= 0 ? '(x − $r)' : '(x + ${-r})';
  return _p(
      MathSkill.quadratics,
      '${terms.join(' ')} = 0: larger root?',
      larger,
      'Factor: ${factor(r1)}${factor(r2)} = 0 → x = ${signed(r1, leading: true)} or ${signed(r2, leading: true)}',
      signed: true,
      cue: 'Quadratic');
}

MathProblem simultaneousProblem(int x, int y) => _p(
    MathSkill.simultaneous,
    'x + y = ${signed(x + y, leading: true)}, x − y = ${signed(x - y, leading: true)}: x = ?',
    x,
    'Add the equations: 2x = ${signed(2 * x, leading: true)} → x = ${signed(x, leading: true)}',
    signed: true,
    cue: 'Simultaneous');

MathProblem indexLawProblem(int base, int m, int n, String law) {
  final (text, answer, hint) = switch (law) {
    '×' => (
        '$base${_power(m)} × $base${_power(n)} = $baseⁿ, n = ?',
        m + n,
        'Multiplying: add the powers $m + $n = ${m + n}'
      ),
    '÷' => (
        '$base${_power(m + n)} ÷ $base${_power(n)} = $baseⁿ, n = ?',
        m,
        'Dividing: subtract the powers ${m + n} − $n = $m'
      ),
    _ => (
        '($base${_power(m)})${_power(n)} = $baseⁿ, n = ?',
        m * n,
        'Power of a power: multiply $m × $n = ${m * n}'
      ),
  };
  return _p(MathSkill.indexLaws, text, answer, hint, cue: 'Index law');
}

MathProblem functionProblem(int a, int b, int x) {
  final answer = a * x + b;
  return _p(
      MathSkill.functions,
      'f(x) = ${_coefficient(a, 'x')} ${_term(b)}, f(${signed(x, leading: true)}) = ?',
      answer,
      'Replace x with ${signed(x, leading: true)}: $a × ${signed(x)} ${_term(b)} = ${signed(answer, leading: true)}',
      signed: true,
      cue: 'Function');
}

/// Picks a grade 6-9 problem; [scaled] maps the generator's difficulty to a
/// range, [between] draws an integer in a range.
MathProblem secondaryProblem(
  MathLevel level,
  Random random, {
  required int Function(int from, int to) scaled,
  required int Function(int min, int max) between,
}) {
  int nonZero(int lo, int hi) {
    var v = 0;
    while (v == 0) {
      v = between(lo, hi);
    }
    return v;
  }

  final roll = random.nextDouble();
  switch (level) {
    case MathLevel.grade6:
      if (roll < 0.25)
        return bracketsProblem(
            between(2, scaled(9, 30)), between(2, 15), between(2, 9));
      if (roll < 0.5) {
        final d = [2, 3, 4, 5, 6, 8, 10][random.nextInt(7)];
        return fractionOfProblem(
            between(1, d - 1), d, d * between(2, scaled(6, 15)));
      }
      if (roll < 0.75) {
        final p = [10, 20, 25, 50, 75][random.nextInt(5)];
        return percentOfProblem(p, 20 * between(1, scaled(5, 20)));
      }
      final g = between(2, 6);
      final a = g * between(2, 7), b = g * between(2, 7);
      return random.nextBool() || a == b
          ? gcdProblem(a, b)
          : lcmProblem(between(2, 9), between(2, 12));
    case MathLevel.grade7:
      if (roll < 0.4) {
        final op = ['+', '−', '×', '÷'][random.nextInt(4)];
        final range = scaled(10, 25);
        if (op == '÷') {
          final b = nonZero(-9, 9), q = nonZero(-range ~/ 2, range ~/ 2);
          return integerProblem(b * q, '÷', b);
        }
        return integerProblem(
            nonZero(-range, range), op, nonZero(-range, range));
      }
      if (roll < 0.7) {
        return oneStepEquation(between(-scaled(10, 25), scaled(12, 30)),
            ['+', '−', '×', '÷'][random.nextInt(4)], between(2, 12));
      }
      if (roll < 0.85) {
        final p = between(1, 5), q = between(1, 7);
        return ratioProblem((p + q) * between(2, scaled(6, 15)), p, q);
      }
      return percentChangeProblem(
          20 * between(1, scaled(5, 15)), [10, 20, 25, 50][random.nextInt(4)],
          increase: random.nextBool());
    case MathLevel.grade8:
      if (roll < 0.25) {
        final base = between(2, scaled(5, 12));
        final maxExp = base <= 3 ? scaled(4, 6) : (base <= 5 ? 3 : 2);
        return random.nextDouble() < 0.6
            ? powerProblem(base, between(2, maxExp))
            : rootProblem(between(2, scaled(12, 20)),
                cube: random.nextDouble() < 0.25);
      }
      if (roll < 0.55)
        return twoStepEquation(between(2, 9), nonZero(-20, 20),
            between(-scaled(5, 12), scaled(8, 15)));
      if (roll < 0.8)
        return substitutionProblem(
            between(2, 6), nonZero(-6, 6), between(-5, 6), between(-5, 6));
      const triples = [(3, 4), (5, 12), (8, 15), (7, 24)];
      final (a, b) = triples[random.nextInt(scaled(1, 4).clamp(1, 4))];
      final k = between(1, 3);
      return pythagorasProblem(a * k, b * k);
    default:
      if (roll < 0.3) {
        final r1 = between(-scaled(5, 9), scaled(5, 9));
        var r2 = between(-scaled(5, 9), scaled(5, 9));
        if (r2 == r1) r2 = r1 + 1;
        return quadraticProblem(r1, r2);
      }
      if (roll < 0.55)
        return simultaneousProblem(
            between(-5, scaled(8, 15)), between(-5, scaled(8, 12)));
      if (roll < 0.75)
        return indexLawProblem(between(2, 9), between(2, 6), between(2, 5),
            ['×', '÷', '^'][random.nextInt(3)]);
      return functionProblem(nonZero(-5, 6), nonZero(-12, 12), between(-6, 8));
  }
}
