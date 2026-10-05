import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'food.dart';
import 'quantity.dart';

const _microgram = '\u00B5g';

const _ingredientAliases = <String, String>{
  'nutritional yeast': 'fortified premium yeast flakes',
  'oatmeal': 'oats',
  'erythritol powder': 'erythritol',
};

class MeasuredMass {
  const new(this.grams, this.unitLabel);

  final double grams;
  final String unitLabel;
}

class DailyValues {
  const new({required this.calories, required this.amounts, required this.names});

  final double calories;
  final Map<String, MeasuredMass> amounts;
  final List<String> names;
}

class Ingredient implements Food {
  new({
    required this.name,
    required this.servingSize,
    required this.servings,
    required this.totalPrice,
    required this.servingNutrition,
  }) : assert(servings > 0, 'A container needs at least one serving');

  @override
  final String name;
  final Quantity servingSize;
  @override
  final double servings;
  @override
  final Price totalPrice;
  @override
  final Nutrients servingNutrition;

  @override
  Price get servingPrice => totalPrice / servings;

  @override
  Nutrients get totalNutrition => servingNutrition * servings;

  IngredientAmount? used(Quantity quantity) {
    final ratio = quantity.ratioTo(servingSize);
    if (ratio == null || ratio.isNaN || ratio.isInfinite) return null;
    return IngredientAmount(this, quantity, ratio);
  }
}

class IngredientAmount implements Food {
  const new(this.ingredient, this.quantity, this.servings);

  final Ingredient ingredient;
  final Quantity quantity;

  @override
  String get name => ingredient.name;

  @override
  final double servings;

  @override
  Price get servingPrice => ingredient.servingPrice;

  @override
  Price get totalPrice => servingPrice * servings;

  @override
  Nutrients get servingNutrition => ingredient.servingNutrition;

  @override
  Nutrients get totalNutrition => servingNutrition * servings;
}

class RecipeLine {
  const new(this.text, {this.food, this.group, this.optional = false});

  final String text;
  final IngredientAmount? food;
  final String? group;
  final bool optional;
}

class Recipe implements Food {
  new({
    required this.name,
    required this.meals,
    required this.servings,
    required this.servingsSpecified,
    required this.calculatesNutrition,
    required this.lines,
    required this.directions,
  }) : assert(servings > 0, 'A recipe needs at least one serving');

  @override
  final String name;
  final List<String> meals;
  @override
  final double servings;
  final bool servingsSpecified;
  final bool calculatesNutrition;
  final List<RecipeLine> lines;
  final List<String> directions;

  bool get isPriced {
    if (!calculatesNutrition) return false;
    var anyRequired = false;
    for (final line in lines) {
      if (line.optional) continue;
      anyRequired = true;
      if (line.food == null) return false;
    }
    return anyRequired;
  }

  @override
  Price get totalPrice => isPriced ? _sumPrices() : const Price(0);

  @override
  Price get servingPrice => totalPrice / servings;

  @override
  Nutrients get totalNutrition => isPriced ? _sumNutrition() : const Nutrients();

  @override
  Nutrients get servingNutrition => totalNutrition / servings;

  Price _sumPrices() {
    var dollars = 0.0;
    for (final food in _requiredFoods()) {
      dollars += food.totalPrice.dollars;
    }
    return Price(dollars);
  }

  Nutrients _sumNutrition() {
    var sum = const Nutrients();
    for (final food in _requiredFoods()) {
      sum += food.totalNutrition;
    }
    return sum;
  }

  Iterable<IngredientAmount> _requiredFoods() sync* {
    for (final line in lines) {
      if (line.optional) continue;
      final food = line.food;
      if (food != null) yield food;
    }
  }
}

extension type Ingredients(Map<String, Ingredient> _byName) {
  Ingredient operator [](String name) {
    final found = _byName[name.toLowerCase()];
    if (found == null) {
      throw ArgumentError('Unknown ingredient: $name');
    }
    return found;
  }
}

extension type Recipes(List<Recipe> _recipes) implements Iterable<Recipe> {
  Recipe operator [](String name) {
    for (final recipe in _recipes) {
      if (recipe.name == name) return recipe;
    }
    throw ArgumentError('Unknown recipe: $name');
  }
}

late final Ingredients ingredients;
late final Recipes recipes;
late final DailyValues dailyValues;

List<String> get meals {
  final names = <String>[];
  for (final recipe in recipes) {
    for (final name in recipe.meals) {
      if (!names.contains(name)) names.add(name);
    }
  }
  return names;
}

Future<void> loadCatalog() async {
  final recipeYaml = await rootBundle.loadString('yaml/recipes.yaml');
  final ingredientYaml = await rootBundle.loadString('yaml/ingredient_data.yaml');
  final dailyValueYaml = await rootBundle.loadString('yaml/daily_values.yaml');
  final parsed = _parseIngredients(_asMap(loadYaml(ingredientYaml) as Object?));
  ingredients = Ingredients(parsed);
  recipes = Recipes(_parseRecipes(_asMap(loadYaml(recipeYaml) as Object?), parsed));
  dailyValues = _parseDailyValues(_asMap(loadYaml(dailyValueYaml) as Object?));
}

YamlMap _asMap(Object? document) {
  if (document is! YamlMap) {
    throw const FormatException('Expected a YAML map');
  }
  return document;
}

Map<String, Ingredient> _parseIngredients(YamlMap document) {
  final ingredients = <String, Ingredient>{};
  for (final key in document.keys) {
    if (key is! String) {
      throw FormatException('Expected an ingredient name, got $key');
    }
    final value = document[key] as Object?;
    if (value is! YamlMap) {
      throw FormatException('Expected data for $key');
    }
    final ingredient = Ingredient(
      name: key,
      servingSize: parseQuantity(_string(value, 'serving size')),
      servings: _number(value, 'servings per container'),
      totalPrice: Price(_number(value, 'container price')),
      servingNutrition: _parseNutrition(_map(value, 'nutrition facts')),
    );
    ingredients[key.toLowerCase()] = ingredient;
  }
  return ingredients;
}

DailyValues _parseDailyValues(YamlMap document) {
  var calories = 0.0;
  final amounts = <String, MeasuredMass>{};
  final names = <String>[];
  for (final key in document.keys) {
    if (key is! String) {
      throw FormatException('Expected a nutrient name, got $key');
    }
    names.add(key);
    final measurement = _measurement(document[key] as Object?, key);
    if (key == 'Calories') {
      calories = measurement.value;
      continue;
    }
    final unit = measurement.unit;
    if (unit == null || unit == 'Cal') {
      throw FormatException('Expected a mass for $key');
    }
    amounts[key] = MeasuredMass(_toGrams(measurement.value, unit), unit);
  }
  return DailyValues(calories: calories, amounts: amounts, names: names);
}

List<Recipe> _parseRecipes(YamlMap document, Map<String, Ingredient> ingredients) {
  final recipes = <Recipe>[];
  for (final key in document.keys) {
    if (key is! String) {
      throw FormatException('Expected a recipe name, got $key');
    }
    final value = document[key] as Object?;
    if (value is! YamlMap) {
      throw FormatException('Expected data for $key');
    }
    final rawServings = value['servings'] as Object?;
    final servingsSpecified = rawServings != null;
    recipes.add(
      Recipe(
        name: key,
        meals: _meals(_string(value, 'meal')),
        servings: servingsSpecified ? _asDouble(rawServings, '$key servings') : 1,
        servingsSpecified: servingsSpecified,
        calculatesNutrition: _calculates(value),
        lines: _lines(value['ingredients'] as Object?, ingredients, key),
        directions: _texts(value['directions'] as Object?, '$key directions'),
      ),
    );
  }
  return recipes;
}

bool _calculates(YamlMap recipe) {
  for (final key in recipe.keys) {
    if (key is String && key.startsWith('calculate')) {
      return recipe[key] != false;
    }
  }
  return true;
}

List<String> _meals(String text) {
  return [
    for (final part in text.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

List<RecipeLine> _lines(Object? value, Map<String, Ingredient> ingredients, String recipe) {
  if (value is! YamlList) {
    throw FormatException('Expected ingredients for $recipe');
  }
  final lines = <RecipeLine>[];
  for (final item in value) {
    if (item is String) {
      lines.add(_line(item, ingredients));
      continue;
    }
    if (item is! YamlMap || item.keys.length != 1) {
      throw FormatException('Unreadable ingredient in $recipe');
    }
    final group = item.keys.single as Object?;
    final children = item.values.single as Object?;
    if (group is! String || children is! YamlList) {
      throw FormatException('Unreadable ingredient group in $recipe');
    }
    for (final child in children) {
      if (child is! String) {
        throw FormatException('Expected text in $recipe $group');
      }
      lines.add(_line(child, ingredients, group: group));
    }
  }
  return lines;
}

RecipeLine _line(String text, Map<String, Ingredient> ingredients, {String? group}) {
  final parsed = tryParseAmount(text);
  IngredientAmount? food;
  if (parsed != null && parsed.name.isNotEmpty) {
    food = ingredients[_canonicalName(parsed.name)]?.used(parsed.quantity);
  }
  return RecipeLine(
    text,
    food: food,
    group: group,
    optional: text.toLowerCase().contains('(optional)'),
  );
}

String _canonicalName(String name) {
  var key = name.toLowerCase();
  final parenthesis = key.indexOf('(');
  if (parenthesis != -1) key = key.substring(0, parenthesis);
  key = key.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (key.endsWith(',')) key = key.substring(0, key.length - 1).trim();
  return _ingredientAliases[key] ?? key;
}

Nutrients _parseNutrition(YamlMap document) {
  var calories = 0.0;
  final grams = <String, double>{};
  void add(String key, Object? value) {
    if (key == 'Vitamins') {
      final vitamins = value;
      if (vitamins is! YamlMap) {
        throw const FormatException('Expected a vitamins map');
      }
      for (final vitamin in vitamins.keys) {
        if (vitamin is! String) {
          throw FormatException('Expected a vitamin name, got $vitamin');
        }
        add(vitamin, vitamins[vitamin] as Object?);
      }
      return;
    }
    final measurement = _measurement(value, key);
    if (key == 'Calories' || measurement.unit == 'Cal') {
      calories = measurement.value;
      return;
    }
    final unit = measurement.unit;
    if (unit == null) {
      throw FormatException('Expected a unit for $key');
    }
    grams[key] = _toGrams(measurement.value, unit);
  }

  for (final key in document.keys) {
    if (key is! String) {
      throw FormatException('Expected a nutrient name, got $key');
    }
    add(key, document[key] as Object?);
  }
  return Nutrients(calories: calories, grams: grams);
}

({double value, String? unit}) _measurement(Object? value, String label) {
  if (value is num) return (value: value.toDouble(), unit: null);
  if (value is! String) {
    throw FormatException('Expected a measurement for $label');
  }
  final match = _measure.firstMatch(value.trim());
  if (match == null) {
    throw FormatException('Unreadable measurement for $label: $value');
  }
  final rawUnit = match.namedGroup('unit');
  return (
    value: double.parse(match.namedGroup('number')!),
    unit: rawUnit == null ? null : _unit(rawUnit),
  );
}

final _measure = RegExp(r'^(?<number>[0-9]+(?:\.[0-9]+)?)\s*(?<unit>\S+)?$');

String _unit(String raw) {
  final unit = raw.replaceAll('\u03BC', '\u00B5').toLowerCase();
  return switch (unit) {
    'g' => 'g',
    'mg' => 'mg',
    _microgram || 'ug' || 'mcg' => _microgram,
    'cal' || 'kcal' => 'Cal',
    _ => throw FormatException('Unknown unit: $raw'),
  };
}

double _toGrams(double value, String unit) => switch (unit) {
  'g' => value,
  'mg' => value / 1000,
  _microgram => value / 1000000,
  _ => throw FormatException('Not a mass unit: $unit'),
};

String _string(YamlMap map, String field) {
  final value = map[field] as Object?;
  if (value is String) return value;
  throw FormatException('Expected text for $field');
}

double _number(YamlMap map, String field) => _asDouble(map[field] as Object?, field);

double _asDouble(Object? value, String label) {
  if (value is num) return value.toDouble();
  throw FormatException('Expected a number for $label');
}

YamlMap _map(YamlMap map, String field) {
  final value = map[field] as Object?;
  if (value is YamlMap) return value;
  throw FormatException('Expected a map for $field');
}

List<String> _texts(Object? value, String label) {
  if (value is! YamlList) {
    throw FormatException('Expected a list for $label');
  }
  final texts = <String>[];
  for (final item in value) {
    if (item is! String) {
      throw FormatException('Expected text in $label');
    }
    texts.add(item);
  }
  return texts;
}
