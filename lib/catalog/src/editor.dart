part of '../catalog.dart';

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
