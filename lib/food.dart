abstract interface class Food {
  String get name;
  double get servings;
  Price get servingPrice;
  Price get totalPrice;
  NutritionFacts get servingNutrition;
  NutritionFacts get totalNutrition;
}

class const Price(final double dollars) {
  @override
  String toString() => '\$${dollars.toStringAsFixed(2)}';
}

abstract class NutritionFacts {
  double get calories;
}

class Tag {
  const new(this.short, {String? full}) : full = full ?? short;
  final String short;
  final String full;
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

  double? get inGrams;
  double? get inMilliliters;

  static const BaseUnit g = BaseUnit(
    UnitName('g', full: 'gram', fullPlural: 'grams'), //
    inGrams: 1.0,
  );
  static const Unit mg = Unit(
    UnitName('mg', full: 'milligram', fullPlural: 'milligrams'),
    baseUnit: g,
    unitsPerBaseUnit: 1000.0,
  );

  static const BaseUnit lb = BaseUnit(
    UnitName('lb', full: 'pound', fullPlural: 'pounds'),
    inGrams: 453.59237,
  );
  static const Unit oz = Unit(
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

  static const BaseUnit cup = BaseUnit(
    UnitName('cup', plural: 'cups', superShort: 'c'),
    inMilliliters: 240.0,
  );
  static const Unit tbsp = Unit(
    UnitName('tbsp', full: 'tablespoon', fullPlural: 'tablespoons', superShort: 'T'),
    baseUnit: cup,
    unitsPerBaseUnit: 16.0,
  );
  static const Unit tsp = Unit(
    UnitName('tsp', full: 'teaspoon', fullPlural: 'teaspoons', superShort: 't'),
    baseUnit: tbsp,
    unitsPerBaseUnit: 3.0,
  );
  static const Unit flOz = Unit(
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
  double? get inGrams => switch (baseUnit.inGrams) {
    final double baseGrams => baseGrams / unitsPerBaseUnit,
    null => null,
  };

  @override
  double? get inMilliliters => switch (baseUnit.inMilliliters) {
    final double baseMilliliters => baseMilliliters / unitsPerBaseUnit,
    null => null,
  };
}

class BaseUnit extends Unit {
  const new(super.name, {this.inGrams, this.inMilliliters})
    : assert((inGrams == null) != (inMilliliters == null)),
      super._();

  @override
  final double? inGrams;

  @override
  final double? inMilliliters;
}
