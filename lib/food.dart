abstract interface class Food {
  String get name;
  double get servings;
  Price get servingPrice;
  Price get totalPrice;
  NutritionFacts get servingNutrition;
  NutritionFacts get totalNutrition;
}

class const Price(final double dollars) {
  Price operator +(Price other) => Price(dollars + other.dollars);

  Price operator *(double factor) => Price(dollars * factor);

  Price operator /(double divisor) => Price(dollars / divisor);

  @override
  String toString() => '\$${dollars.toStringAsFixed(2)}';
}

class NutritionFacts {
  const new({required this.calories, required this.grams});

  final double calories;

  /// Mass nutrients in grams, keyed by the names used in the catalog files.
  final Map<String, double> grams;

  static const none = NutritionFacts(calories: 0, grams: {});

  NutritionFacts operator +(NutritionFacts other) {
    final combined = <String, double>{};
    for (final MapEntry(:key, :value) in grams.entries) {
      combined[key] = value;
    }
    for (final MapEntry(:key, :value) in other.grams.entries) {
      combined[key] = (combined[key] ?? 0) + value;
    }
    return NutritionFacts(calories: calories + other.calories, grams: combined);
  }

  NutritionFacts operator *(double factor) => NutritionFacts(
    calories: calories * factor,
    grams: {for (final MapEntry(:key, :value) in grams.entries) key: value * factor},
  );

  NutritionFacts operator /(double divisor) => this * (1 / divisor);
}

class UnitName {
  const new(this.short, {String? full, String? superShort, String? plural, String? fullPlural})
    : full = full ?? short,
      superShort = superShort ?? short,
      plural = plural ?? short,
      fullPlural = fullPlural ?? plural ?? full ?? short;

  final String short;
  final String full;
  final String superShort;
  final String plural;
  final String fullPlural;

  @override
  String toString() => full;
}

sealed class Unit {
  const factory(UnitName name, {required Unit baseUnit, required double unitsPerBaseUnit}) = _Unit;

  const new _(this.name);

  /// "oz" and "ounce" are the weight ounce.
  factory fromName(String raw) {
    final match = matchLeading(raw.trim());
    if (match == null || match.rest.isNotEmpty) {
      throw FormatException('Unknown unit: $raw');
    }
    return match.unit;
  }

  static ({Unit unit, String rest})? matchLeading(String text) {
    final folded = text.replaceAll('\u03BC', '\u00B5');
    for (final spelling in _unitSpellings) {
      if (!_hasSpellingPrefix(folded, spelling)) continue;
      return (unit: spelling.unit, rest: text.substring(spelling.text.length).trim());
    }
    return null;
  }

  final UnitName name;

  double get inGrams;
  double get inMilliliters;

  /// True when this unit is defined by weight. The other measure is water at 1 g/ml.
  bool get measuresMass;

  static const g = BaseUnit(
    UnitName('g', full: 'gram', fullPlural: 'grams'), //
    inGrams: 1.0,
  );
  static const mg = Unit(
    UnitName('mg', full: 'milligram', fullPlural: 'milligrams'),
    baseUnit: g,
    unitsPerBaseUnit: 1000.0,
  );
  static const mcg = Unit(
    UnitName('\u00B5g', full: 'microgram', fullPlural: 'micrograms', superShort: 'mcg'),
    baseUnit: g,
    unitsPerBaseUnit: 1000000.0,
  );

  static const lb = BaseUnit(
    UnitName('lb', full: 'pound', fullPlural: 'pounds'),
    inGrams: 453.59237,
  );
  static const oz = Unit(
    UnitName('oz', full: 'ounce', fullPlural: 'ounces'),
    baseUnit: lb,
    unitsPerBaseUnit: 16.0,
  );

  static const liter = BaseUnit(
    UnitName('liter', plural: 'liters', superShort: 'l'),
    inMilliliters: 1000.0,
  );
  static const ml = BaseUnit(
    UnitName('ml', full: 'milliliter', fullPlural: 'milliliters'),
    inMilliliters: 1.0,
  );

  static const cup = BaseUnit(
    UnitName('cup', plural: 'cups', superShort: 'c'),
    inMilliliters: 240.0,
  );
  static const tbsp = Unit(
    UnitName('tbsp', full: 'tablespoon', fullPlural: 'tablespoons', superShort: 'T'),
    baseUnit: cup,
    unitsPerBaseUnit: 16.0,
  );
  static const tsp = Unit(
    UnitName('tsp', full: 'teaspoon', fullPlural: 'teaspoons', superShort: 't'),
    baseUnit: tbsp,
    unitsPerBaseUnit: 3.0,
  );
  static const flOz = Unit(
    UnitName('fl. oz', full: 'fluid ounce', fullPlural: 'fluid ounces'),
    baseUnit: cup,
    unitsPerBaseUnit: 8.0,
  );
}

class _Unit extends Unit {
  const new(super.name, {required this.baseUnit, required this.unitsPerBaseUnit}) : super._();

  final Unit baseUnit;

  final double unitsPerBaseUnit;

  @override
  double get inGrams => baseUnit.inGrams / unitsPerBaseUnit;

  @override
  double get inMilliliters => baseUnit.inMilliliters / unitsPerBaseUnit;

  @override
  bool get measuresMass => baseUnit.measuresMass;
}

class BaseUnit extends Unit {
  const new(super.name, {double? inGrams, double? inMilliliters})
    : assert((inGrams == null) != (inMilliliters == null)),
      measuresMass = inGrams != null,
      inGrams = inGrams ?? inMilliliters ?? 0,
      inMilliliters = inMilliliters ?? inGrams ?? 0,
      super._();

  @override
  final bool measuresMass;

  @override
  final double inGrams;

  @override
  final double inMilliliters;
}

class _UnitSpelling {
  const new(this.text, this.unit, {required this.caseSensitive});

  final String text;
  final Unit unit;
  final bool caseSensitive;
}

final List<_UnitSpelling> _unitSpellings = _buildUnitSpellings();

List<_UnitSpelling> _buildUnitSpellings() {
  const units = <Unit>[.mcg, .mg, .g, .oz, .lb, .ml, .liter, .tsp, .tbsp, .flOz, .cup];
  final spellings = <_UnitSpelling>[];
  void add(String text, Unit unit) {
    if (text.isEmpty) return;
    final caseSensitive = text.length == 1;
    for (final existing in spellings) {
      final sameText = caseSensitive
          ? existing.text == text
          : existing.text.toLowerCase() == text.toLowerCase();
      if (!sameText) continue;
      return;
    }
    spellings.add(_UnitSpelling(text, unit, caseSensitive: caseSensitive));
  }

  for (final unit in units) {
    final UnitName(:fullPlural, :full, :plural, :short, :superShort) = unit.name;
    add(fullPlural, unit);
    add(full, unit);
    add(plural, unit);
    add(short, unit);
    add(superShort, unit);
  }
  spellings.sort((a, b) => b.text.length.compareTo(a.text.length));
  return spellings;
}

bool _hasSpellingPrefix(String text, _UnitSpelling spelling) {
  final alias = spelling.text;
  if (text.length < alias.length) return false;
  final head = text.substring(0, alias.length);
  final matches = spelling.caseSensitive
      ? head == alias
      : head.toLowerCase() == alias.toLowerCase();
  if (!matches) return false;
  if (text.length == alias.length) return true;
  return text[alias.length].trim().isEmpty;
}
