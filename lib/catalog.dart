import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import 'food.dart';
import 'measure.dart';

const _microgram = '\u00B5g';

@visibleForTesting
const ignoredIngredientNames = <String>{
  'water',
  'red food coloring',
  'plant-based sausage, bell peppers, jalapeños, diced red onion, etc.',
};

@visibleForTesting
const ingredientAliases = <String, String>{
  'erythritol powder': 'erythritol',
  'sweetener': 'sucralose',
  'nutritional yeast': 'fortified premium yeast flakes',
  'oil': 'canola oil',
  'sourdough starter': 'whole wheat flour',
};

class Ingredient implements Food {
  new({
    required this.name,
    required this.servingSize,
    required this.servings,
    required this.totalPrice,
    required this.servingNutrition,
    this.measurementText = const {},
  }) : assert(servings > 0, 'A container needs at least one serving');

  @override
  final String name;
  final Measure servingSize;
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

class RecipeLine {
  const new(this.text, {this.food, this.group, this.optional = false, this.ignored = false});

  final String text;
  final IngredientAmount? food;
  final String? group;
  final bool optional;
  final bool ignored;
}

class Recipe implements Food {
  new({
    required this.name,
    required this.tags,
    required this.servings,
    required this.servingsSpecified,
    required this.calculatesNutrition,
    required this.lines,
    required this.directions,
  }) : assert(servings > 0, 'A recipe needs at least one serving');

  @override
  final String name;
  final List<String> tags;
  @override
  final double servings;
  final bool servingsSpecified;
  final bool calculatesNutrition;
  final List<RecipeLine> lines;
  final List<String> directions;

  late final bool isPriced = _hasPrice();

  @override
  late final Price totalPrice = isPriced ? _sumPrices() : const Price(0);

  @override
  late final NutritionFacts totalNutrition = isPriced ? _sumNutrition() : .none;

  late final String _searchText = _searchableText();

  @override
  Price get servingPrice => totalPrice / servings;

  @override
  NutritionFacts get servingNutrition => totalNutrition / servings;

  bool matches(String? tag, String query) {
    if (tag != null && !tags.contains(tag)) return false;
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return _searchText.contains(normalized);
  }

  bool _hasPrice() {
    if (!calculatesNutrition) return false;
    var anyRequired = false;
    for (final line in lines) {
      if (line.optional || line.ignored) continue;
      anyRequired = true;
      if (line.food == null) return false;
    }
    return anyRequired;
  }

  Price _sumPrices() {
    var dollars = 0.0;
    for (final line in lines) {
      if (line case RecipeLine(optional: false, ignored: false, :final food?)) {
        dollars += food.totalPrice.dollars;
      }
    }
    return Price(dollars);
  }

  NutritionFacts _sumNutrition() {
    NutritionFacts sum = .none;
    for (final line in lines) {
      if (line case RecipeLine(optional: false, ignored: false, :final food?)) {
        sum += food.totalNutrition;
      }
    }
    return sum;
  }

  String _searchableText() {
    final haystack = StringBuffer(name);
    for (final tag in tags) {
      haystack
        ..write('\n')
        ..write(tag);
    }
    for (final line in lines) {
      haystack
        ..write('\n')
        ..write(line.text);
    }
    for (final direction in directions) {
      haystack
        ..write('\n')
        ..write(direction);
    }
    return haystack.toString().toLowerCase();
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
late final Map<String, Measure> dailyValues;

List<String> get tags {
  final names = <String>[];
  for (final recipe in recipes) {
    for (final name in recipe.tags) {
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
  if (document is! YamlMap) throw const FormatException('Expected a YAML map');
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
    final nutrition = _parseNutrition(_map(value, 'nutrition facts'));
    final ingredient = Ingredient(
      name: key,
      servingSize: parseMeasure(_string(value, 'serving size')),
      servings: _number(value, 'servings per container'),
      totalPrice: Price(_number(value, 'container price')),
      servingNutrition: nutrition.facts,
      measurementText: nutrition.measurements,
    );
    ingredients[key.toLowerCase()] = ingredient;
  }
  return ingredients;
}

Map<String, Measure> _parseDailyValues(YamlMap document) {
  final measurements = <String, Measure>{};
  for (final key in document.keys) {
    if (key is! String) {
      throw FormatException('Expected a nutrient name, got $key');
    }
    if (key == 'Calories') continue;
    final raw = document[key] as Object?;
    final unit = _measurement(raw, key).unit;
    if (unit == null || unit == 'Cal') {
      throw FormatException('Expected a mass for $key');
    }
    measurements[key] = Measure.parse(_measurementString(raw, key));
  }
  return measurements;
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
        tags: _tags(_string(value, 'tags')),
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

List<String> _tags(String text) {
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
  final name = parsed == null || parsed.name.isEmpty ? text : parsed.name;
  final ignored = ignoredIngredientNames.contains(_normalized(name));
  IngredientAmount? food;
  if (parsed != null && parsed.name.isNotEmpty) {
    food = ingredients[_canonicalName(parsed.name)]?.used(parsed.measure);
  }
  return RecipeLine(
    text,
    food: food,
    group: group,
    optional: text.toLowerCase().contains('(optional)'),
    ignored: ignored,
  );
}

String _normalized(String name) {
  var key = name.toLowerCase();
  final parenthesis = key.indexOf('(');
  if (parenthesis != -1) key = key.substring(0, parenthesis);
  key = key.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (key.endsWith(',')) key = key.substring(0, key.length - 1).trim();
  return key;
}

String _canonicalName(String name) {
  name = _normalized(name);
  return ingredientAliases[name] ?? name;
}

@visibleForTesting
RecipeLine recipeLineFor(String text, Map<String, Ingredient> pantry, {String? group}) =>
    _line(text, pantry, group: group);

({NutritionFacts facts, Map<String, String> measurements}) _parseNutrition(YamlMap document) {
  var calories = 0.0;
  final grams = <String, double>{};
  final measurements = <String, String>{};
  void add(String key, Object? value) {
    if (key == 'Vitamins') {
      if (value is! YamlMap) {
        throw const FormatException('Expected a vitamins map');
      }
      for (final vitamin in value.keys) {
        if (vitamin is! String) {
          throw FormatException('Expected a vitamin name, got $vitamin');
        }
        add(vitamin, value[vitamin] as Object?);
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
    measurements[key] = _measurementString(value, key);
    grams[key] = _toGrams(measurement.value, unit);
  }

  for (final key in document.keys) {
    if (key is! String) {
      throw FormatException('Expected a nutrient name, got $key');
    }
    add(key, document[key] as Object?);
  }
  return (facts: NutritionFacts(calories: calories, grams: grams), measurements: measurements);
}

String _measurementString(Object? value, String label) {
  if (value is String) return value.trim();
  if (value is int) return '$value';
  if (value is double) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }
  throw FormatException('Expected a measurement for $label');
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
