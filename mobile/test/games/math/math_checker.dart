import 'dart:math';

// An independent checker for generated math problems: parses the problem
// text (with its own tiny expression parser) and works the answer out, so
// tests never reuse the generator's arithmetic.

const _superscripts = {
  '⁰': '0',
  '¹': '1',
  '²': '2',
  '³': '3',
  '⁴': '4',
  '⁵': '5',
  '⁶': '6',
  '⁷': '7',
  '⁸': '8',
  '⁹': '9',
  'ⁿ': 'n',
};

String _normalize(String text) {
  var s = text.replaceAll('−', '-').replaceAll('×', '*').replaceAll('÷', '/');
  final out = StringBuffer();
  var inPower = false;
  for (final ch in s.split('')) {
    final sup = _superscripts[ch];
    if (sup != null) {
      if (!inPower) out.write('^');
      inPower = true;
      out.write(sup);
    } else {
      inPower = false;
      out.write(ch);
    }
  }
  return out.toString();
}

class _Parser {
  _Parser(String source, this.vars) : src = source.replaceAll(' ', '');

  final String src;
  final Map<String, double> vars;
  var i = 0;

  double parse() {
    final v = _expr();
    if (i != src.length) throw FormatException('trailing input', src, i);
    return v;
  }

  String? get _peek => i < src.length ? src[i] : null;

  double _expr() {
    var v = _term();
    while (_peek == '+' || _peek == '-') {
      final op = src[i++];
      final r = _term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double _term() {
    var v = _power();
    while (true) {
      final c = _peek;
      if (c == '*' || c == '/') {
        i++;
        final r = _power();
        v = c == '*' ? v * r : v / r;
      } else if (c != null && (RegExp(r'[a-z(√∛]').hasMatch(c))) {
        v *= _power(); // implicit multiplication: 3x, 2(…)
      } else {
        return v;
      }
    }
  }

  double _power() {
    final base = _unary();
    if (_peek == '^') {
      i++;
      return pow(base, _unary()).toDouble();
    }
    return base;
  }

  double _unary() {
    if (_peek == '-') {
      i++;
      return -_power();
    }
    return _primary();
  }

  double _primary() {
    final c = _peek;
    if (c == '(') {
      i++;
      final v = _expr();
      i++; // ')'
      return v;
    }
    if (c == '√') {
      i++;
      return sqrt(_primary());
    }
    if (c == '∛') {
      i++;
      return pow(_primary(), 1 / 3).toDouble();
    }
    final number = RegExp(r'\d+').matchAsPrefix(src, i);
    if (number != null) {
      i = number.end;
      return double.parse(number.group(0)!);
    }
    if (c != null && vars.containsKey(c)) {
      i++;
      return vars[c]!;
    }
    throw FormatException('unexpected', src, i);
  }
}

double evalExpr(String expr, [Map<String, double> vars = const {}]) =>
    _Parser(_normalize(expr), vars).parse();

/// Relative tolerance: index-law problems reach values like 8³⁰.
bool _close(double a, double b) =>
    (a - b).abs() <= 1e-6 * max(1.0, max(a.abs(), b.abs()));

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// The answer worked out from the problem text alone.
int solveProblem(String text) {
  final t = _normalize(text);
  RegExpMatch? m;
  if ((m = RegExp(r'^(\d+)/(\d+) of (\d+)$').firstMatch(t)) != null) {
    return int.parse(m!.group(1)!) *
        int.parse(m.group(3)!) ~/
        int.parse(m.group(2)!);
  }
  if ((m = RegExp(r'^(\d+)% of (\d+)$').firstMatch(t)) != null) {
    return int.parse(m!.group(1)!) * int.parse(m.group(2)!) ~/ 100;
  }
  if ((m = RegExp(r'^(GCD|LCM)\((\d+), (\d+)\)$').firstMatch(t)) != null) {
    final a = int.parse(m!.group(2)!), b = int.parse(m.group(3)!);
    return m.group(1) == 'GCD' ? _gcd(a, b) : a * b ~/ _gcd(a, b);
  }
  if ((m = RegExp(r'^Share (\d+) in ratio (\d+):(\d+)\. Larger part\?$')
          .firstMatch(t)) !=
      null) {
    final total = int.parse(m!.group(1)!),
        p = int.parse(m.group(2)!),
        q = int.parse(m.group(3)!);
    return total ~/ (p + q) * max(p, q);
  }
  if ((m = RegExp(r'^(Increase|Decrease) (\d+) by (\d+)%$').firstMatch(t)) !=
      null) {
    final base = int.parse(m!.group(2)!),
        change = base * int.parse(m.group(3)!) ~/ 100;
    return m.group(1) == 'Increase' ? base + change : base - change;
  }
  if ((m = RegExp(r'^Legs (\d+) and (\d+): hypotenuse\?$').firstMatch(t)) !=
      null) {
    final a = int.parse(m!.group(1)!), b = int.parse(m.group(2)!);
    return sqrt(a * a + b * b).round();
  }
  if ((m = RegExp(r'^(.*) when a = (-?\d+), b = (-?\d+)$').firstMatch(t)) !=
      null) {
    return evalExpr(m!.group(1)!, {
      'a': double.parse(m.group(2)!),
      'b': double.parse(m.group(3)!)
    }).round();
  }
  if ((m = RegExp(r'^f\(x\) = (.*), f\((-?\d+)\) = \?$').firstMatch(t)) !=
      null) {
    return evalExpr(m!.group(1)!, {'x': double.parse(m.group(2)!)}).round();
  }
  if ((m = RegExp(r'^x \+ y = (-?\d+), x - y = (-?\d+): x = \?$')
          .firstMatch(t)) !=
      null) {
    return (int.parse(m!.group(1)!) + int.parse(m.group(2)!)) ~/ 2;
  }
  if ((m = RegExp(r'^(.*) = 0: larger root\?$').firstMatch(t)) != null) {
    final roots = [
      for (var x = -60; x <= 60; x++)
        if (_close(evalExpr(m!.group(1)!, {'x': x.toDouble()}), 0)) x,
    ];
    return roots.reduce(max);
  }
  if ((m = RegExp(r'^(.*) = (\d+)\^n, n = \?$').firstMatch(t)) != null) {
    final lhs = evalExpr(m!.group(1)!), base = int.parse(m.group(2)!);
    return [for (var n = 0; n < 40; n++) n]
        .firstWhere((n) => _close(pow(base.toDouble(), n).toDouble(), lhs));
  }
  if ((m = RegExp(r'^(.*) = (-?\d+), x = \?$').firstMatch(t)) != null) {
    final rhs = double.parse(m!.group(2)!);
    return [for (var x = -600; x <= 600; x++) x].firstWhere(
        (x) => _close(evalExpr(m!.group(1)!, {'x': x.toDouble()}), rhs));
  }
  final v = evalExpr(t);
  if (!_close(v, v.roundToDouble())) throw StateError('non-integer $text = $v');
  return v.round();
}
