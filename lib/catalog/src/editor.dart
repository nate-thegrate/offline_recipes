part of '../catalog.dart';

Recipe rebindRecipe(Recipe recipe, List<Ingredient> pantry) {
  return Recipe(
    name: recipe.name,
    tags: recipe.tags,
    servings: recipe.servings,
    servingsSpecified: recipe.servingsSpecified,
    calculatesNutrition: recipe.calculatesNutrition,
    lines: [for (final line in recipe.lines) _line(line.text, pantry, group: line.group)],
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

Recipe recipeFromEditor({
  required String name,
  required String tags,
  required String servings,
  required bool calculatesNutrition,
  required String ingredientText,
  required List<String> directions,
}) {
  final servingText = servings.trim();
  return Recipe(
    name: _requiredName(name),
    tags: _tags(tags),
    servings: servingText.isEmpty ? 1 : _positiveNumber(servingText, 'Servings'),
    servingsSpecified: servingText.isNotEmpty,
    calculatesNutrition: calculatesNutrition,
    lines: _linesFromText(ingredientText, ingredients),
    directions: [
      for (final direction in directions)
        if (direction.trim().isNotEmpty) direction,
    ],
  );
}

({String text, Measure measure}) _servingMeasure(String servingSize) {
  final text = servingSize.trim();
  if (text.isEmpty) {
    throw const FormatException('Enter a serving size, such as 1 cup');
  }
  try {
    return (text: text, measure: parseMeasure(text));
  } on FormatException {
    throw const FormatException('Enter a serving size, such as 1 cup');
  }
}

Map<String, String> _nutrientAmounts(List<({String name, String amount})> nutrients) {
  final amounts = <String, String>{};
  for (final (:name, :amount) in nutrients) {
    final nutrientName = name.trim();
    final nutrientAmount = amount.trim();
    if (nutrientName.isEmpty && nutrientAmount.isEmpty) continue;
    if (nutrientName.isEmpty || nutrientAmount.isEmpty) {
      throw const FormatException('Enter both a nutrient name and an amount');
    }
    if (nutrientName.toLowerCase() == 'calories') {
      throw const FormatException('Enter calories in the calories field');
    }
    if (amounts.containsKey(nutrientName)) {
      throw FormatException('$nutrientName is listed twice');
    }
    amounts[nutrientName] = nutrientAmount;
  }
  return amounts;
}

List<RecipeLine> _linesFromText(String text, List<Ingredient> pantry) {
  final lines = <RecipeLine>[];
  String? group;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (_isGroupHeader(line)) {
      group = line.substring(0, line.length - 1).trim();
      continue;
    }
    lines.add(_line(line, pantry, group: group));
  }
  return lines;
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
