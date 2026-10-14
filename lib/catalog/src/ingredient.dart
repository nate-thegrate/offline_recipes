part of '../catalog.dart';

class Ingredient implements Food {
  new({
    required this.name,
    required this.servingSize,
    required this.servings,
    required this.totalPrice,
    required this.servingNutrition,
    this.measurementText = const {},
    String? servingSizeText,
  }) : servingSizeText = servingSizeText ?? formatMeasure(servingSize),
       assert(servings > 0, 'A container needs at least one serving');

  @override
  final String name;
  final Measure servingSize;

  /// Serving size as written, such as "1 cup" or "100 g".
  final String servingSizeText;
  @override
  final double servings;
  @override
  final Price totalPrice;
  @override
  final NutritionFacts servingNutrition;

  /// Mass amounts as written in the catalog, in file order.
  final Map<String, String> measurementText;

  @override
  Price get servingPrice => totalPrice / servings;

  @override
  NutritionFacts get totalNutrition => servingNutrition * servings;

  IngredientAmount? used(Measure measure) {
    final ratio = _servingsIn(measure);
    if (ratio != null && ratio.isFinite) return IngredientAmount(this, measure, ratio);
    return null;
  }

  // Mass and volume agree while a serving has no measurement of its own.
  double? _servingsIn(Measure measure) {
    final alongMass = measure.unit.measuresMass;
    final serving = alongMass ? servingSize.grams : servingSize.milliliters;
    if (serving == 0) return null;
    final amount = alongMass ? measure.grams : measure.milliliters;
    return amount / serving;
  }
}

class IngredientAmount implements Food {
  const new(this.ingredient, this.measure, this.servings);

  final Ingredient ingredient;
  final Measure measure;

  @override
  String get name => ingredient.name;

  @override
  final double servings;

  @override
  Price get servingPrice => ingredient.servingPrice;

  @override
  Price get totalPrice => servingPrice * servings;

  @override
  NutritionFacts get servingNutrition => ingredient.servingNutrition;

  @override
  NutritionFacts get totalNutrition => servingNutrition * servings;
}
