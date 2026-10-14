import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:signal_widgets/signal_widgets.dart';
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

  /// Null when the recipe is one batch.
  String? get specifiedServings => servingsSpecified ? servings.plainNumber : null;

  String get ingredientLinesText {
    final buffer = StringBuffer();
    String? group;
    for (final line in lines) {
      if (line.group != group) {
        if (buffer.isNotEmpty) buffer.writeln();
        group = line.group;
        if (group != null) buffer.writeln('$group:');
      }
      buffer.writeln(line.text);
    }
    return buffer.toString().trimRight();
  }

  bool matches(Iterable<String> requiredTags, String query) {
    for (final tag in requiredTags) {
      if (!tags.contains(tag)) return false;
    }
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

final ingredients = listSignal(<Ingredient>[]);
final recipes = listSignal(<Recipe>[]);

Ingredient? findIngredient(String name) => _namedIngredient(ingredients, name);

Ingredient? _namedIngredient(Iterable<Ingredient> pantry, String name) {
  final key = name.toLowerCase();
  for (final ingredient in pantry) {
    if (ingredient.name.toLowerCase() == key) return ingredient;
  }
  return null;
}

Recipe? findRecipe(String name) {
  for (final recipe in recipes) {
    if (recipe.name == name) return recipe;
  }
  return null;
}

/// Recipe open in the browser. Replaced when a catalog edit rebuilds that recipe.
final selected = signal<Recipe?>(null);

final List<Ingredient> _bundledIngredients = [];
final List<Recipe> _bundledRecipes = [];

List<Ingredient> get bundledIngredients => List.unmodifiable(_bundledIngredients);
List<Recipe> get bundledRecipes => List.unmodifiable(_bundledRecipes);

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
  final parsedRecipes = _parseRecipes(_asMap(loadYaml(recipeYaml) as Object?), parsed);
  dailyValues = _parseDailyValues(_asMap(loadYaml(dailyValueYaml) as Object?));
  _bundledIngredients
    ..clear()
    ..addAll(parsed);
  _bundledRecipes
    ..clear()
    ..addAll(parsedRecipes);
  publishCatalog(List<Ingredient>.of(parsed), List<Recipe>.of(parsedRecipes));
}

void publishCatalog(List<Ingredient> pantry, List<Recipe> next, {String? focus}) {
  ingredients.value = pantry;
  recipes.value = next;
  final target = focus ?? selected.peek()?.name;
  if (target == null) return;
  selected.value = findRecipe(target);
}

@visibleForTesting
void debugResetCatalog() {
  publishCatalog(List<Ingredient>.of(bundledIngredients), List<Recipe>.of(bundledRecipes));
}

Map<dynamic, dynamic> _asMap(Object? document) {
  if (document is! Map) throw const FormatException('Expected a YAML map');
  return document;
}

List<Ingredient> _parseIngredients(Map<dynamic, dynamic> document) {
  final pantry = <String, Ingredient>{};
  for (final key in document.keys) {
    if (key is! String) {
      throw FormatException('Expected an ingredient name, got $key');
    }
    final value = document[key] as Object?;
    if (value is! Map) {
      throw FormatException('Expected data for $key');
    }
    final nutrition = _parseNutrition(_map(value, 'nutrition facts'));
    final servingSize = _string(value, 'serving size');
    final ingredient = Ingredient(
      name: key,
      servingSize: parseMeasure(servingSize),
      servingSizeText: servingSize,
      servings: _number(value, 'servings per container'),
      totalPrice: Price(_number(value, 'container price')),
      servingNutrition: nutrition.facts,
      measurementText: nutrition.measurements,
    );
    pantry[key.toLowerCase()] = ingredient;
  }
  return pantry.values.toList();
}

Map<String, Measure> _parseDailyValues(Map<dynamic, dynamic> document) {
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

List<Recipe> _parseRecipes(Map<dynamic, dynamic> document, List<Ingredient> pantry) {
  final recipes = <Recipe>[];
  for (final key in document.keys) {
    if (key is! String) {
      throw FormatException('Expected a recipe name, got $key');
    }
    final value = document[key] as Object?;
    if (value is! Map) {
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
        lines: _lines(value['ingredients'] as Object?, pantry, key),
        directions: _texts(value['directions'] as Object?, '$key directions'),
      ),
    );
  }
  return recipes;
}

bool _calculates(Map<dynamic, dynamic> recipe) {
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

List<RecipeLine> _lines(Object? value, List<Ingredient> pantry, String recipe) {
  if (value is! List) {
    throw FormatException('Expected ingredients for $recipe');
  }
  final lines = <RecipeLine>[];
  for (final item in value) {
    if (item is String) {
      lines.add(_line(item, pantry));
      continue;
    }
    if (item is! Map || item.keys.length != 1) {
      throw FormatException('Unreadable ingredient in $recipe');
    }
    final group = item.keys.single as Object?;
    final children = item.values.single as Object?;
    if (group is! String || children is! List) {
      throw FormatException('Unreadable ingredient group in $recipe');
    }
    for (final child in children) {
      if (child is! String) {
        throw FormatException('Expected text in $recipe $group');
      }
      lines.add(_line(child, pantry, group: group));
    }
  }
  return lines;
}

RecipeLine _line(String text, List<Ingredient> pantry, {String? group}) {
  final parsed = tryParseAmount(text);
  final name = parsed == null || parsed.name.isEmpty ? text : parsed.name;
  final ignored = ignoredIngredientNames.contains(_normalized(name));
  IngredientAmount? food;
  if (parsed != null && parsed.name.isNotEmpty) {
    food = _namedIngredient(pantry, _canonicalName(parsed.name))?.used(parsed.measure);
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
RecipeLine recipeLineFor(String text, List<Ingredient> pantry, {String? group}) =>
    _line(text, pantry, group: group);

({NutritionFacts facts, Map<String, String> measurements}) _parseNutrition(
  Map<dynamic, dynamic> document,
) {
  var calories = 0.0;
  final grams = <String, double>{};
  final measurements = <String, String>{};
  void add(String key, Object? value) {
    if (key == 'Vitamins') {
      if (value is! Map) {
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
  if (value is num) return value.toDouble().plainNumber;
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

String _string(Map<dynamic, dynamic> map, String field) {
  final value = map[field] as Object?;
  if (value is String) return value;
  throw FormatException('Expected text for $field');
}

double _number(Map<dynamic, dynamic> map, String field) => _asDouble(map[field] as Object?, field);

double _asDouble(Object? value, String label) {
  if (value is num) return value.toDouble();
  throw FormatException('Expected a number for $label');
}

Map<dynamic, dynamic> _map(Map<dynamic, dynamic> map, String field) {
  final value = map[field] as Object?;
  if (value is Map) return value;
  throw FormatException('Expected a map for $field');
}

List<String> _texts(Object? value, String label) {
  if (value is! List) {
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

Ingredient parseIngredient(String name, Map<String, Object?> fields) {
  return _parseIngredients(<dynamic, dynamic>{name: fields}).single;
}

Recipe parseRecipe(String name, Map<String, Object?> fields, List<Ingredient> pantry) {
  return _parseRecipes(<dynamic, dynamic>{name: fields}, pantry).single;
}

Recipe rebindRecipe(Recipe recipe, List<Ingredient> pantry) {
  return Recipe(
    name: recipe.name,
    tags: recipe.tags,
    servings: recipe.servings,
    servingsSpecified: recipe.servingsSpecified,
    calculatesNutrition: recipe.calculatesNutrition,
    lines: [for (final line in recipe.lines) recipeLineFor(line.text, pantry, group: line.group)],
    directions: recipe.directions,
  );
}

Map<String, Object?> ingredientDocument(Ingredient ingredient) {
  return {
    'serving size': ingredient.servingSizeText,
    'servings per container': ingredient.servings,
    'container price': ingredient.totalPrice.dollars,
    'nutrition facts': {
      'Calories': '${ingredient.servingNutrition.calories.plainNumber} Cal',
      for (final MapEntry(:key, :value) in ingredient.measurementText.entries) key: value,
    },
  };
}

Map<String, Object?> recipeDocument(Recipe recipe) {
  return {
    'tags': recipe.tags.join(', '),
    if (recipe.servingsSpecified) 'servings': recipe.servings,
    if (!recipe.calculatesNutrition) 'calculate nutrition & price': false,
    'ingredients': _ingredientItems(recipe.lines),
    'directions': recipe.directions,
  };
}

List<Object> _ingredientItems(List<RecipeLine> lines) {
  final items = <Object>[];
  String? group;
  List<String>? grouped;
  void flush() {
    final name = group;
    final texts = grouped;
    if (name == null || texts == null) return;
    items.add({name: texts});
    group = null;
    grouped = null;
  }

  for (final line in lines) {
    if (line.group == null) {
      flush();
      items.add(line.text);
      continue;
    }
    if (line.group != group) {
      flush();
      group = line.group;
      grouped = <String>[];
    }
    grouped!.add(line.text);
  }
  flush();
  return items;
}

String directionForField(String stored) => stored.replaceAll('<br>', '\n');

String directionFromField(String field) {
  final stored = field.replaceAll('\n', '<br>');
  if (stored.replaceAll('<br>', '').trim().isEmpty) return '';
  return stored;
}

Ingredient ingredientFromEditor({
  required String name,
  required String servingSize,
  required String servings,
  required String price,
  required String calories,
  required List<({String name, String amount})> nutrients,
}) {
  final ingredientName = _requiredName(name);
  final servingText = servingSize.trim();
  if (servingText.isEmpty) {
    throw const FormatException('Enter a serving size, such as 1 cup');
  }
  try {
    parseMeasure(servingText);
  } on FormatException {
    throw const FormatException('Enter a serving size, such as 1 cup');
  }
  final measurements = <String, String>{};
  for (final nutrient in nutrients) {
    final nutrientName = nutrient.name.trim();
    final amount = nutrient.amount.trim();
    if (nutrientName.isEmpty && amount.isEmpty) continue;
    if (nutrientName.isEmpty || amount.isEmpty) {
      throw const FormatException('Enter both a nutrient name and an amount');
    }
    if (nutrientName.toLowerCase() == 'calories') {
      throw const FormatException('Enter calories in the calories field');
    }
    if (measurements.containsKey(nutrientName)) {
      throw FormatException('$nutrientName is listed twice');
    }
    measurements[nutrientName] = amount;
  }
  return parseIngredient(ingredientName, {
    'serving size': servingText,
    'servings per container': _positiveNumber(servings, 'Servings per container'),
    'container price': _price(price),
    'nutrition facts': {'Calories': '${_calories(calories).plainNumber} Cal', ...measurements},
  });
}

Recipe recipeFromEditor({
  required String name,
  required String tags,
  required String servings,
  required bool calculatesNutrition,
  required String ingredientText,
  required List<String> directions,
}) {
  final servingText = servings.trim();
  return parseRecipe(_requiredName(name), {
    'tags': tags,
    if (servingText.isNotEmpty) 'servings': _positiveNumber(servingText, 'Servings'),
    if (!calculatesNutrition) 'calculate nutrition & price': false,
    'ingredients': _ingredientListFromText(ingredientText),
    'directions': [
      for (final direction in directions)
        if (direction.trim().isNotEmpty) direction,
    ],
  }, ingredients);
}

List<Object> _ingredientListFromText(String text) {
  final items = <Object>[];
  String? group;
  List<String>? grouped;
  void flush() {
    final name = group;
    final texts = grouped;
    if (name == null || texts == null) return;
    items.add({name: texts});
    group = null;
    grouped = null;
  }

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (_isGroupHeader(line)) {
      flush();
      group = line.substring(0, line.length - 1).trim();
      grouped = <String>[];
      continue;
    }
    if (group == null) {
      items.add(line);
    } else {
      grouped!.add(line);
    }
  }
  flush();
  return items;
}

bool _isGroupHeader(String line) {
  if (!line.endsWith(':')) return false;
  final name = line.substring(0, line.length - 1).trim();
  if (name.isEmpty) return false;
  return tryParseAmount(name) == null;
}

String _requiredName(String text) {
  final name = text.trim();
  if (name.isEmpty) throw const FormatException('Enter a name');
  return name;
}

double _positiveNumber(String text, String label) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) throw FormatException('Enter $label');
  final parsed = double.tryParse(trimmed);
  if (parsed == null) throw FormatException('Enter $label as a number');
  if (parsed <= 0) throw FormatException('$label must be greater than zero');
  return parsed;
}

double _price(String text) {
  final trimmed = text.trim().replaceAll(r'$', '').replaceAll(',', '');
  if (trimmed.isEmpty) throw const FormatException('Enter a container price');
  final parsed = double.tryParse(trimmed);
  if (parsed == null) throw const FormatException('Enter a container price');
  if (parsed < 0) throw const FormatException('Price cannot be negative');
  return parsed;
}

double _calories(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  final number = trimmed
      .replaceAll(',', '')
      .replaceAll(RegExp(r'cal', caseSensitive: false), '')
      .trim();
  final parsed = double.tryParse(number);
  if (parsed == null) throw const FormatException('Enter calories as a number');
  if (parsed < 0) throw const FormatException('Calories cannot be negative');
  return parsed;
}
