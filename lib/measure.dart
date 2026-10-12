import 'food.dart';

enum UnitNames { full, short, superShort }

String labelAmount(double amount) => switch (amount) {
  > 0 && < 10 => amount.toStringAsFixed(1),
  _ => amount.round().toString(),
};

String _unitSpelling(UnitName name, double amount, UnitNames names) {
  final plural = amount > 1;
  return switch (names) {
    .full => plural ? name.fullPlural : name.full,
    .short => plural ? name.plural : name.short,
    .superShort => name.superShort,
  };
}

/// Rewrites a leading measure in [source]. Amounts such as "1 1/2" stay as written.
String displayIngredient(String source, UnitNames names) {
  final text = source.trim();
  final parsed = tryParseAmount(text);
  if (parsed == null) return source;
  final spelling = _unitSpelling(parsed.measure.unit.name, parsed.measure.amount, names);
  final prefix = text.substring(0, parsed.amountEnd);
  final tail = text.substring(parsed.unitEnd);
  return '$prefix $spelling$tail';
}

class Measure {
  const new(this.amount, this.unit);

  factory parse(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.first.isEmpty) {
      throw FormatException('Cannot read a measure from "$text"');
    }
    var amount = _Rational.parse(words.first);
    var index = 1;
    if (index < words.length && _startsWithDigit(words[index])) {
      amount += _Rational.parse(words[index]);
      index++;
    }
    if (index >= words.length) {
      throw FormatException('Expected a unit in "$text"');
    }
    return Measure(amount.value, Unit.fromName(words[index]));
  }

  final double amount;
  final Unit unit;

  double get grams => amount * unit.inGrams;

  double get milliliters => amount * unit.inMilliliters;

  Measure operator +(Measure other) {
    final kept = _largerUnit(unit, other.unit);
    return Measure(_amountIn(amount, unit, kept) + _amountIn(other.amount, other.unit, kept), kept);
  }

  Measure operator *(double factor) => Measure(amount * factor, unit);

  /// Quotient of the two amounts in grams. Volume units count as water, 1 g/ml.
  double operator /(Measure other) => grams / other.grams;

  Measure perServing(double servings) => this * (1 / servings);

  String percentOf(Measure daily) => '${((this / daily) * 100).round()}%';

  String get quantityText => '${labelAmount(amount)}${unit.name.short}';
}

class ParsedAmount {
  const new(this.measure, this.name, {required this.amountEnd, required this.unitEnd});

  final Measure measure;

  /// Ingredient name after the unit. Empty when the text is only a measure.
  final String name;

  /// Exclusive end of the written amount in the trimmed source.
  final int amountEnd;

  /// Exclusive end of the leading unit spelling in the trimmed source.
  final int unitEnd;
}

Measure parseMeasure(String text) {
  final parsed = tryParseAmount(text);
  if (parsed == null || parsed.name.isNotEmpty) {
    throw FormatException('Not a measure: $text');
  }
  return parsed.measure;
}

ParsedAmount? tryParseAmount(String text) {
  final trimmed = text.trim();
  final match = _amount.firstMatch(trimmed);
  if (match == null) return null;
  final whole = match.namedGroup('whole');
  final double amount;
  if (whole != null) {
    final denominator = int.parse(match.namedGroup('mixedDenominator')!);
    if (denominator == 0) return null;
    amount = int.parse(whole) + int.parse(match.namedGroup('mixedNumerator')!) / denominator;
  } else {
    final numerator = match.namedGroup('numerator');
    if (numerator != null) {
      final denominator = int.parse(match.namedGroup('denominator')!);
      if (denominator == 0) return null;
      amount = int.parse(numerator) / denominator;
    } else {
      amount = double.parse(match.namedGroup('decimal')!);
    }
  }
  final rawRest = match.namedGroup('rest')!;
  final leading = Unit.matchLeading(rawRest);
  if (leading == null) return null;
  final restStart = match.end - rawRest.length;
  return ParsedAmount(
    Measure(amount, leading.unit),
    leading.rest.trim(),
    amountEnd: trimmed.substring(0, restStart).trimRight().length,
    unitEnd: restStart + rawRest.length - leading.rest.length,
  );
}

final _amount = RegExp(
  r'^(?:(?<whole>\d+)\s+(?<mixedNumerator>\d+)/(?<mixedDenominator>\d+)'
  r'|(?<numerator>\d+)/(?<denominator>\d+)'
  r'|(?<decimal>\d+(?:\.\d+)?))\s+(?<rest>.+)$',
);

class _Rational {
  const new(this.numerator, this.denominator);

  factory parse(String token) {
    if (token.contains('/')) {
      final pieces = token.split('/');
      if (pieces.length != 2 || pieces[1] == '0') {
        throw FormatException('Bad fraction: $token');
      }
      return _Rational(int.parse(pieces[0]), int.parse(pieces[1]));
    }
    final dot = token.indexOf('.');
    if (dot == -1) return _Rational(int.parse(token), 1);
    final fraction = token.substring(dot + 1);
    final scale = int.parse('1${'0' * fraction.length}');
    final whole = token.substring(0, dot);
    final wholeValue = whole.isEmpty ? 0 : int.parse(whole);
    return _Rational(wholeValue * scale + int.parse(fraction), scale);
  }

  final int numerator;
  final int denominator;

  _Rational operator +(_Rational other) {
    return _Rational(
      numerator * other.denominator + other.numerator * denominator,
      denominator * other.denominator,
    );
  }

  double get value => numerator / denominator;
}

bool _startsWithDigit(String token) {
  if (token.isEmpty) return false;
  final code = token.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}

double _amountIn(double amount, Unit from, Unit to) => amount * from.inGrams / to.inGrams;

Unit _largerUnit(Unit a, Unit b) {
  if (a.measuresMass != b.measuresMass) {
    throw StateError('Cannot compare ${a.name.short} with ${b.name.short}');
  }
  return a.inGrams >= b.inGrams ? a : b;
}
