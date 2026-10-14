import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signal_widgets/signal_widgets.dart';
import 'package:yaml/yaml.dart';

import 'package:offline_recipes/food.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/utils/matching_list.dart';

part 'src/ingredient.dart';
part 'src/recipe.dart';
part 'src/parse.dart';
part 'src/editor.dart';
part 'src/edits.dart';

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

final ingredients = MatchingList(_matchingIngredients);
List<Ingredient> _matchingIngredients(String query) {
  return [
    for (final ingredient in ingredients)
      if (ingredient.name.toLowerCase().contains(query)) ingredient,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

final recipes = MatchingList(_matchingRecipes);
List<Recipe> _matchingRecipes(String query) {
  final requiredTags = selectedTags.value;
  return [
    for (final recipe in recipes)
      if (recipe.matches(requiredTags, query)) recipe,
  ];
}

/// Tags a recipe must have to show in the browser. Empty shows every recipe.
final selectedTags = setSignal(<String>{});

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
