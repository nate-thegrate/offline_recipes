part of '../catalog.dart';

const _editsKey = 'catalogEdits';

class CatalogEdits {
  const new({
    this.ingredients = const {},
    this.deletedIngredients = const {},
    this.recipes = const {},
    this.deletedRecipes = const {},
  });

  factory fromJson(Map<dynamic, dynamic> json) {
    return CatalogEdits(
      ingredients: _documents(json['ingredients']),
      deletedIngredients: _names(json['deletedIngredients']),
      recipes: _documents(json['recipes']),
      deletedRecipes: _names(json['deletedRecipes']),
    );
  }

  final Map<String, Map<String, Object?>> ingredients;
  final Set<String> deletedIngredients;
  final Map<String, Map<String, Object?>> recipes;
  final Set<String> deletedRecipes;

  bool get isEmpty =>
      ingredients.isEmpty &&
      deletedIngredients.isEmpty &&
      recipes.isEmpty &&
      deletedRecipes.isEmpty;

  Map<String, Object?> toJson() => {
    'ingredients': ingredients,
    'deletedIngredients': deletedIngredients.toList(),
    'recipes': recipes,
    'deletedRecipes': deletedRecipes.toList(),
  };

  CatalogEdits copyWith({
    Map<String, Map<String, Object?>>? ingredients,
    Set<String>? deletedIngredients,
    Map<String, Map<String, Object?>>? recipes,
    Set<String>? deletedRecipes,
  }) {
    return CatalogEdits(
      ingredients: ingredients ?? this.ingredients,
      deletedIngredients: deletedIngredients ?? this.deletedIngredients,
      recipes: recipes ?? this.recipes,
      deletedRecipes: deletedRecipes ?? this.deletedRecipes,
    );
  }

  static Future<CatalogEdits> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_editsKey);
    if (raw == null || raw.isEmpty) return const CatalogEdits();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Catalog edits are not a map');
    return CatalogEdits.fromJson(decoded);
  }

  Future<void> write() async {
    final preferences = await SharedPreferences.getInstance();
    if (isEmpty) {
      await preferences.remove(_editsKey);
      return;
    }
    await preferences.setString(_editsKey, jsonEncode(toJson()));
  }
}

Future<void> reloadCatalogEdits() async {
  applyCatalogEdits(await CatalogEdits.read());
}

void applyCatalogEdits(CatalogEdits edits, {String? focus}) {
  final pantry = <Ingredient>[
    for (final ingredient in bundledIngredients)
      if (!edits.deletedIngredients.contains(ingredient.name.toLowerCase())) ingredient,
  ];
  for (final MapEntry(:key, :value) in edits.ingredients.entries) {
    if (edits.deletedIngredients.contains(key.toLowerCase())) continue;
    final ingredient = Ingredient.parse(key, value);
    final index = pantry.indexWhere(
      (item) => item.name.toLowerCase() == ingredient.name.toLowerCase(),
    );
    if (index == -1) {
      pantry.add(ingredient);
    } else {
      pantry[index] = ingredient;
    }
  }

  final next = <Recipe>[
    for (final recipe in bundledRecipes)
      if (!edits.deletedRecipes.contains(recipe.name)) recipe.rebind(pantry),
  ];
  for (final MapEntry(:key, :value) in edits.recipes.entries) {
    if (edits.deletedRecipes.contains(key)) continue;
    final recipe = Recipe.parse(key, value, pantry);
    final index = next.indexWhere((item) => item.name == recipe.name);
    if (index == -1) {
      next.add(recipe);
    } else {
      next[index] = recipe;
    }
  }
  publishCatalog(pantry, next, focus: focus);
}

Future<void> saveIngredient(Ingredient ingredient, {String? previousName}) async {
  final name = ingredient.name;
  if (previousName?.toLowerCase() != name.toLowerCase() && ingredients.findByName(name) != null) {
    throw FormatException('An ingredient named $name already exists');
  }
  final edits = await CatalogEdits.read();
  final documents = {...edits.ingredients};
  final deleted = {...edits.deletedIngredients};
  if (previousName != null && previousName.toLowerCase() != name.toLowerCase()) {
    _removeIngredient(documents, previousName);
    deleted.add(previousName.toLowerCase());
  }
  _removeIngredient(documents, name);
  deleted.remove(name.toLowerCase());
  documents[name] = ingredient.document;
  final next = edits.copyWith(ingredients: documents, deletedIngredients: deleted);
  await next.write();
  applyCatalogEdits(next);
}

Future<void> deleteIngredient(String name) async {
  final edits = await CatalogEdits.read();
  final documents = {...edits.ingredients};
  _removeIngredient(documents, name);
  final next = edits.copyWith(
    ingredients: documents,
    deletedIngredients: {...edits.deletedIngredients, name.toLowerCase()},
  );
  await next.write();
  applyCatalogEdits(next);
}

Future<void> saveRecipe(Recipe recipe, {String? previousName}) async {
  if (previousName != recipe.name && recipes.findByName(recipe.name) != null) {
    throw FormatException('A recipe named ${recipe.name} already exists');
  }
  final edits = await CatalogEdits.read();
  final documents = {...edits.recipes};
  final deleted = {...edits.deletedRecipes};
  if (previousName != null && previousName != recipe.name) {
    documents.remove(previousName);
    deleted.add(previousName);
  }
  deleted.remove(recipe.name);
  documents[recipe.name] = recipe.document;
  final next = edits.copyWith(recipes: documents, deletedRecipes: deleted);
  await next.write();
  applyCatalogEdits(next, focus: recipe.name);
}

Future<void> deleteRecipe(String name) async {
  final edits = await CatalogEdits.read();
  final documents = {...edits.recipes}..remove(name);
  final next = edits.copyWith(recipes: documents, deletedRecipes: {...edits.deletedRecipes, name});
  await next.write();
  applyCatalogEdits(next);
}

void _removeIngredient(Map<String, Map<String, Object?>> documents, String name) {
  final lower = name.toLowerCase();
  documents.removeWhere((key, _) => key.toLowerCase() == lower);
}

Map<String, Map<String, Object?>> _documents(Object? value) {
  if (value == null) return {};
  if (value is! Map) throw const FormatException('Expected catalog entries');
  final documents = <String, Map<String, Object?>>{};
  for (final key in value.keys) {
    if (key is! String) throw FormatException('Expected a name, got $key');
    final fields = value[key];
    if (fields is! Map) throw FormatException('Expected data for $key');
    documents[key] = Map<String, Object?>.from(fields);
  }
  return documents;
}

Set<String> _names(Object? value) {
  if (value == null) return {};
  if (value is! List) throw const FormatException('Expected a list of names');
  final names = <String>{};
  for (final item in value) {
    if (item is! String) throw const FormatException('Expected a name');
    names.add(item);
  }
  return names;
}
