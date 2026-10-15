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

final _sortedIngredients = computed(_sortIngredients);

List<Ingredient> _sortIngredients() {
  final sorted = [...ingredients];
  sorted.sort((a, b) => a.lowercaseName.compareTo(b.lowercaseName));
  return sorted;
}

List<Ingredient> _matchingIngredients(String query) {
  final sorted = _sortedIngredients.value;
  if (query.isEmpty) return sorted;
  return [
    for (final ingredient in sorted)
      if (ingredient.lowercaseName.contains(query)) ingredient,
  ];
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

Map<String, Ingredient> _indexByName(Iterable<Ingredient> pantry) => {
  for (final ingredient in pantry) ingredient.lowercaseName: ingredient,
};

extension IngredientNames on Iterable<Ingredient> {
  Ingredient? findByName(String name) {
    final key = name.toLowerCase();
    for (final ingredient in this) {
      if (ingredient.lowercaseName == key) return ingredient;
    }
    return null;
  }
}

extension RecipeNames on Iterable<Recipe> {
  Recipe? findByName(String name) {
    for (final recipe in this) {
      if (recipe.name == name) return recipe;
    }
    return null;
  }
}

/// Recipe open in the browser. Replaced when a catalog edit rebuilds that recipe.
final selected = signal<Recipe?>(null);

final List<Ingredient> _bundledIngredients = [];
final List<Recipe> _bundledRecipes = [];

List<Ingredient> get bundledIngredients => List.unmodifiable(_bundledIngredients);
List<Recipe> get bundledRecipes => List.unmodifiable(_bundledRecipes);

late final Map<String, Measure> dailyValues;

final _tagNames = computed(_collectTags);

/// Tag names in the order recipes first mention them.
List<String> get tags => _tagNames.value;

List<String> _collectTags() {
  final names = <String>{};
  for (final recipe in recipes) {
    names.addAll(recipe.tags);
  }
  return names.toList();
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
  selected.value = recipes.findByName(target);
}

@visibleForTesting
void debugResetCatalog() {
  publishCatalog(List<Ingredient>.of(bundledIngredients), List<Recipe>.of(bundledRecipes));
}
