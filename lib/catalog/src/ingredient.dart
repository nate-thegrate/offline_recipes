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
  }) : servingSizeText = servingSizeText ?? servingSize.plainText,
       assert(servings > 0, 'A container needs at least one serving');

  factory parse(String name, Map<String, Object?> fields) {
    final data = fields as Map<dynamic, dynamic>;
    final nutrition = _parseNutrition(_map(data, 'nutrition facts'));
    final servingSize = _string(data, 'serving size');
    return Ingredient(
      name: name,
      servingSize: Measure.parseExact(servingSize),
      servingSizeText: servingSize,
      servings: _number(data, 'servings per container'),
      totalPrice: Price(_number(data, 'container price')),
      servingNutrition: nutrition.facts,
      measurementText: nutrition.measurements,
    );
  }

  factory fromEditor({
    required String name,
    required String servingSize,
    required String servings,
    required String price,
    required String calories,
    required List<({String name, String amount})> nutrients,
  }) {
    final ingredientName = _requiredName(name);
    final (:text, :measure) = _servingMeasure(servingSize);
    final amounts = _nutrientAmounts(nutrients);
    final servingCount = _positiveNumber(servings, 'Servings per container');
    final containerPrice = _price(price);
    final nutrition = _nutritionFromAmounts(_calories(calories), amounts);
    return Ingredient(
      name: ingredientName,
      servingSize: measure,
      servingSizeText: text,
      servings: servingCount,
      totalPrice: Price(containerPrice),
      servingNutrition: nutrition.facts,
      measurementText: nutrition.measurements,
    );
  }

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

  Map<String, Object?> get document => {
    'serving size': servingSizeText,
    'servings per container': servings,
    'container price': totalPrice.dollars,
    'nutrition facts': {
      'Calories': '${servingNutrition.calories.plainNumber} Cal',
      for (final MapEntry(:key, :value) in measurementText.entries) key: value,
    },
  };

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
