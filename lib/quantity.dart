import 'food.dart';

class Quantity {
  const new(this.amount, this.unit);

  final double amount;
  final Unit unit;

  double? get grams {
    final unitGrams = unit.inGrams;
    if (unitGrams == null) return null;
    return amount * unitGrams;
  }

  double? get milliliters {
    final unitMilliliters = unit.inMilliliters;
    if (unitMilliliters == null) return null;
    return amount * unitMilliliters;
  }

  /// How many [serving]s this amount is, or null when the units measure different things.
  double? ratioTo(Quantity serving) {
    final measured = grams;
    final servingMeasured = serving.grams;
    if (measured != null && servingMeasured != null) {
      if (servingMeasured == 0) return null;
      return measured / servingMeasured;
    }
    final volume = milliliters;
    final servingVolume = serving.milliliters;
    if (volume != null && servingVolume != null) {
      if (servingVolume == 0) return null;
      return volume / servingVolume;
    }
    return null;
  }
}

class ParsedAmount {
  const new(this.amount, this.unit, this.name);

  final double amount;
  final Unit unit;

  /// Ingredient name after the unit. Empty when the text is only a quantity.
  final String name;

  Quantity get quantity => Quantity(amount, unit);
}

Quantity parseQuantity(String text) {
  final parsed = tryParseAmount(text);
  if (parsed == null || parsed.name.isNotEmpty) {
    throw FormatException('Not a quantity: $text');
  }
  return parsed.quantity;
}

ParsedAmount? tryParseAmount(String text) {
  final match = _amount.firstMatch(text.trim());
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
  final split = _splitUnit(match.namedGroup('rest')!);
  if (split == null) return null;
  final (unit: unit, name: name) = split;
  return ParsedAmount(amount, unit, name);
}

final _amount = RegExp(
  r'^(?:(?<whole>\d+)\s+(?<mixedNumerator>\d+)/(?<mixedDenominator>\d+)'
  r'|(?<numerator>\d+)/(?<denominator>\d+)'
  r'|(?<decimal>\d+(?:\.\d+)?))\s+(?<rest>.+)$',
);

// Weight ounce is listed before fluid ounce so the shared "oz" abbreviation stays a weight.
const _units = <Unit>[.mg, .g, .oz, .lb, .ml, .liter, .tsp, .tbsp, .flOz, .cup];

final List<_Alias> _aliases = _buildAliases();

({Unit unit, String name})? _splitUnit(String rest) {
  for (final alias in _aliases) {
    if (!_hasAliasPrefix(rest, alias.text, caseSensitive: alias.caseSensitive)) continue;
    return (unit: alias.unit, name: rest.substring(alias.text.length).trim());
  }
  return null;
}

bool _hasAliasPrefix(String text, String alias, {required bool caseSensitive}) {
  if (text.length < alias.length) return false;
  final head = text.substring(0, alias.length);
  final matches = caseSensitive ? head == alias : head.toLowerCase() == alias.toLowerCase();
  if (!matches) return false;
  if (text.length == alias.length) return true;
  return text[alias.length].trim().isEmpty;
}

List<_Alias> _buildAliases() {
  final aliases = <_Alias>[];
  void add(String text, Unit unit) {
    if (text.isEmpty) return;
    final caseSensitive = text.length == 1;
    for (final existing in aliases) {
      final sameText = caseSensitive
          ? existing.text == text
          : existing.text.toLowerCase() == text.toLowerCase();
      if (!sameText) continue;
      return;
    }
    aliases.add(_Alias(text, unit, caseSensitive: caseSensitive));
  }

  for (final unit in _units) {
    final UnitName(:fullPlural, :full, :plural, :short, :superShort) = unit.name;
    add(fullPlural, unit);
    add(full, unit);
    add(plural, unit);
    add(short, unit);
    add(superShort, unit);
  }
  aliases.sort((a, b) => b.text.length.compareTo(a.text.length));
  return aliases;
}

class _Alias {
  const new(this.text, this.unit, {required this.caseSensitive});

  final String text;
  final Unit unit;
  final bool caseSensitive;
}
