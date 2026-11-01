/// The curriculum skill each math problem family trains. Ids match
/// `assets/curriculum/math.json`; every generator tags its problems here,
/// so no family can be left out of the mastery map.
abstract final class MathSkill {
  static const addSubWithin20 = 'math.add-sub.within-20';
  static const addSubWithin100 = 'math.add-sub.within-100';
  static const addSubWithin1000 = 'math.add-sub.within-1000';
  static const addSubWithin10000 = 'math.add-sub.within-10000';
  static const tables = 'math.mul-div.tables';
  static const divideFacts = 'math.mul-div.divide-facts';
  static const twoByOne = 'math.mul-div.two-by-one';
  static const divideLarger = 'math.mul-div.divide-larger';
  static const twoByTwo = 'math.mul-div.two-by-two';
  static const orderOfOperations = 'math.arith.order-of-operations';
  static const brackets = 'math.arith.brackets';
  static const gcd = 'math.number.gcd';
  static const lcm = 'math.number.lcm';
  static const fractionOfAmount = 'math.frac.fraction-of-amount';
  static const percentOfAmount = 'math.percent.of-amount';
  static const percentChange = 'math.percent.change';
  static const ratioShare = 'math.ratio.share';
  static const integerOperations = 'math.integers.operations';
  static const oneStepEquations = 'math.algebra.one-step-equations';
  static const twoStepEquations = 'math.algebra.two-step-equations';
  static const substitution = 'math.algebra.substitution';
  static const integerPowers = 'math.powers.integer-powers';
  static const roots = 'math.powers.roots';
  static const pythagoras = 'math.geometry.pythagoras';
  static const quadratics = 'math.algebra.quadratics';
  static const simultaneous = 'math.algebra.simultaneous';
  static const functions = 'math.algebra.functions';
  static const indexLaws = 'math.powers.index-laws';

  /// Every id above, for the test that checks them against the curriculum.
  static const all = [
    addSubWithin20,
    addSubWithin100,
    addSubWithin1000,
    addSubWithin10000,
    tables,
    divideFacts,
    twoByOne,
    divideLarger,
    twoByTwo,
    orderOfOperations,
    brackets,
    gcd,
    lcm,
    fractionOfAmount,
    percentOfAmount,
    percentChange,
    ratioShare,
    integerOperations,
    oneStepEquations,
    twoStepEquations,
    substitution,
    integerPowers,
    roots,
    pythagoras,
    quadratics,
    simultaneous,
    functions,
    indexLaws,
  ];

  /// Adding or subtracting: the skill follows the biggest number involved.
  static String addSub(int largest) {
    if (largest <= 20) return addSubWithin20;
    if (largest <= 100) return addSubWithin100;
    if (largest <= 1000) return addSubWithin1000;
    return addSubWithin10000;
  }

  /// Multiplying: a times-table fact, a 2-digit by 1-digit, or 2 by 2.
  static String multiply(int a, int b) {
    final small = a < b ? a : b;
    final big = a < b ? b : a;
    if (big <= 10) return tables;
    return small <= 9 ? twoByOne : twoByTwo;
  }

  /// Dividing: a table fact (divisor and quotient up to 10) or larger.
  static String divide(int divisor, int quotient) =>
      divisor <= 10 && quotient <= 10 ? divideFacts : divideLarger;
}
