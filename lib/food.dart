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

class Tag {
  const new(this.short, {String? full}) : full = full ?? short;
  final String short;
  final String full;

  @override
  String toString() => full;
}

class UnitName extends Tag {
  const new(super.short, {super.full, String? superShort, String? plural, String? fullPlural})
    : superShort = superShort ?? short,
      plural = plural ?? short,
      fullPlural = fullPlural ?? plural ?? full ?? short;

  final String superShort;
  final String plural;
  final String fullPlural;
}

sealed class Unit {
  const factory(UnitName name, {required Unit baseUnit, required double unitsPerBaseUnit}) = _Unit;

  const new _(this.name);

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
    UnitName('fl. oz', full: 'fluid ounce', fullPlural: 'fluid ounces', superShort: 'oz'),
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
