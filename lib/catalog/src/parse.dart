part of '../catalog.dart';

final _whitespace = RegExp(r'\s+');

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
    pantry[key.toLowerCase()] = Ingredient.parse(key, Map<String, Object?>.from(value));
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
    recipes.add(Recipe.parse(key, Map<String, Object?>.from(value), pantry));
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
  final index = _indexByName(pantry);
  final lines = <RecipeLine>[];
  for (final item in value) {
    if (item is String) {
      lines.add(RecipeLine.parse(item, pantry, index: index));
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
      lines.add(RecipeLine.parse(child, pantry, group: group, index: index));
    }
  }
  return lines;
}

String _normalized(String name) {
  var key = name.toLowerCase();
  final parenthesis = key.indexOf('(');
  if (parenthesis != -1) key = key.substring(0, parenthesis);
  key = key.replaceAll(_whitespace, ' ').trim();
  if (key.endsWith(',')) key = key.substring(0, key.length - 1).trim();
  return key;
}

String _canonicalName(String name) {
  name = _normalized(name);
  return ingredientAliases[name] ?? name;
}

({NutritionFacts facts, Map<String, String> measurements}) _nutritionFromAmounts(
  double calories,
  Map<String, String> amounts,
) {
  final grams = <String, double>{};
  final measurements = <String, String>{};
  for (final MapEntry(:key, :value) in amounts.entries) {
    _storeMass(key, value, _measurement(value, key), grams, measurements);
  }
  return (facts: NutritionFacts(calories: calories, grams: grams), measurements: measurements);
}

void _storeMass(
  String key,
  Object? value,
  ({double value, String? unit}) measurement,
  Map<String, double> grams,
  Map<String, String> measurements,
) {
  final unit = measurement.unit;
  if (unit == null) {
    throw FormatException('Expected a unit for $key');
  }
  measurements[key] = _measurementString(value, key);
  grams[key] = _toGrams(measurement.value, unit);
}

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
    _storeMass(key, value, measurement, grams, measurements);
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
