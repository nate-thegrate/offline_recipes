import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog/catalog.dart';
import 'package:offline_recipes/main.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCatalog);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await loadSettings();
    debugResetSettings();
    selected.value = null;
    selectedTags.clear();
    recipes.controller.clear();
    debugResetCatalog();
  });

  test('editor text keeps groups, optional lines, and direction breaks', () {
    final rolls = recipes.findByName('cinnamon rolls')!;
    final edited = Recipe.fromEditor(
      name: rolls.name,
      tags: rolls.tags.join(', '),
      servings: rolls.specifiedServings ?? '',
      calculatesNutrition: rolls.calculatesNutrition,
      ingredientText: rolls.ingredientLinesText,
      directions: [
        for (final direction in rolls.directions) directionFromField(directionForField(direction)),
      ],
    );

    expect(edited.tags, rolls.tags);
    expect(edited.servings, rolls.servings);
    expect(edited.servingsSpecified, rolls.servingsSpecified);
    expect(edited.calculatesNutrition, rolls.calculatesNutrition);
    expect(edited.directions, rolls.directions);
    expect(
      [
        for (final line in edited.lines)
          (
            line.group,
            line.text,
            line.optional,
            line.ignored,
            line.food?.name,
            line.food?.servings,
          ),
      ],
      [
        for (final line in rolls.lines)
          (
            line.group,
            line.text,
            line.optional,
            line.ignored,
            line.food?.name,
            line.food?.servings,
          ),
      ],
    );
  });

  test('a serving size has to be a measure', () {
    expect(
      () => Ingredient.fromEditor(
        name: 'oat milk',
        servingSize: 'a splash',
        servings: '1',
        price: '1',
        calories: '',
        nutrients: const [],
      ),
      throwsFormatException,
    );
  });

  test('a saved ingredient prices a recipe that uses it, and both survive a reload', () async {
    final before = recipes.length;
    await saveIngredient(_oatMilk(price: '3.00'));
    await saveRecipe(_latte());

    final recipe = recipes.findByName('oat latte')!;
    expect(recipe.isPriced, isTrue);
    expect(recipe.totalPrice.dollars, closeTo(1.5, 1e-9));
    expect(recipe.totalNutrition.calories, closeTo(240, 1e-9));
    expect(recipe.totalNutrition.grams['Protein'], closeTo(16, 1e-9));
    expect(recipe.lines.single.food!.name, 'test oat milk');
    expect(selected.value?.name, 'oat latte');
    expect(recipes.length, before + 1);

    selected.value = null;
    await reloadCatalogEdits();

    final again = recipes.findByName('oat latte')!;
    expect(again.totalPrice.dollars, closeTo(1.5, 1e-9));
    expect(again.totalNutrition.calories, closeTo(240, 1e-9));
    expect(ingredients.findByName('test oat milk')!.totalPrice.dollars, closeTo(3, 1e-9));
    expect(recipes.length, before + 1);
  });

  test('updating an ingredient price changes the recipe and keeps its nutrition', () async {
    await saveIngredient(_oatMilk(price: '3.00'));
    await saveRecipe(_latte());
    final calories = recipes.findByName('oat latte')!.totalNutrition.calories;

    await saveIngredient(_oatMilk(price: '6.00'), previousName: 'test oat milk');

    final recipe = recipes.findByName('oat latte')!;
    expect(recipe.totalPrice.dollars, closeTo(3, 1e-9));
    expect(recipe.totalNutrition.calories, closeTo(calories, 1e-9));
    expect(ingredients.findByName('test oat milk')!.servingPrice.dollars, closeTo(1.5, 1e-9));
  });

  test('deleting an ingredient drops it out of recipes that use it', () async {
    await saveIngredient(_oatMilk(price: '3.00'));
    await saveRecipe(_latte());

    await deleteIngredient('test oat milk');

    final recipe = recipes.findByName('oat latte')!;
    expect(recipe.lines.single.food, isNull);
    expect(recipe.isPriced, isFalse);
    expect(recipe.totalPrice.dollars, 0);
    expect(ingredients.findByName('test oat milk'), isNull);

    await reloadCatalogEdits();
    expect(ingredients.findByName('test oat milk'), isNull);
    expect(recipes.findByName('oat latte')!.lines.single.food, isNull);
  });

  test('updating a built-in ingredient reprices the recipes that use it', () async {
    final flour = ingredients.findByName('whole wheat flour')!;
    final cornbread = recipes.findByName('cornbread')!;
    expect(cornbread.isPriced, isTrue);
    final line = cornbread.lines.firstWhere((item) => item.food?.name == flour.name);
    final oldTotal = cornbread.totalPrice.dollars;
    final oldLine = line.food!.totalPrice.dollars;
    final oldCalories = cornbread.totalNutrition.calories;
    final protein = flour.servingNutrition.grams['Protein'];

    await saveIngredient(
      Ingredient.fromEditor(
        name: flour.name,
        servingSize: flour.servingSizeText,
        servings: flour.servings.plainNumber,
        price: '0.00',
        calories: flour.servingNutrition.calories.plainNumber,
        nutrients: [
          for (final MapEntry(:key, :value) in flour.measurementText.entries)
            (name: key, amount: value),
        ],
      ),
      previousName: flour.name,
    );

    final updated = recipes.findByName('cornbread')!;
    expect(updated.totalPrice.dollars, closeTo(oldTotal - oldLine, 1e-6));
    expect(updated.totalNutrition.calories, closeTo(oldCalories, 1e-6));
    expect(
      updated.lines
          .firstWhere((item) => item.text == line.text)
          .food!
          .servingNutrition
          .grams['Protein'],
      protein,
    );

    await reloadCatalogEdits();
    expect(recipes.findByName('cornbread')!.totalPrice.dollars, closeTo(oldTotal - oldLine, 1e-6));
    expect(ingredients.findByName('whole wheat flour')!.totalPrice.dollars, 0);
  });

  test('a deleted built-in recipe stays gone, and another recipe stays selected', () async {
    final removed = recipes.first;
    final kept = recipes.toList()[1];
    selected.value = kept;

    await deleteRecipe(removed.name);

    expect(recipes.findByName(removed.name), isNull);
    expect(selected.value?.name, kept.name);

    await reloadCatalogEdits();
    expect(recipes.findByName(removed.name), isNull);
    expect(recipes.findByName(kept.name), isNotNull);
    expect(selected.value?.name, kept.name);
  });

  test('renaming a recipe leaves one copy under the new name', () async {
    final original = recipes.findByName('popcorn')!;
    final renamed = Recipe.fromEditor(
      name: 'chili popcorn',
      tags: original.tags.join(', '),
      servings: original.specifiedServings ?? '',
      calculatesNutrition: original.calculatesNutrition,
      ingredientText: original.ingredientLinesText,
      directions: original.directions,
    );

    await saveRecipe(renamed, previousName: original.name);

    expect(recipes.findByName(original.name), isNull);
    expect(recipes.findByName('chili popcorn')!.directions, original.directions);
    expect(selected.value?.name, 'chili popcorn');

    await reloadCatalogEdits();
    expect(recipes.findByName('popcorn'), isNull);
    expect(recipes.findByName('chili popcorn')!.lines.map((line) => line.text), [
      for (final line in original.lines) line.text,
    ]);
  });

  test('a second recipe cannot take an existing name', () async {
    final name = recipes.first.name;
    final count = recipes.length;
    final created = Recipe.fromEditor(
      name: name,
      tags: 'side dish',
      servings: '',
      calculatesNutrition: false,
      ingredientText: '1 cup water',
      directions: const ['Boil.'],
    );

    await expectLater(saveRecipe(created), throwsFormatException);
    expect(recipes.length, count);
    expect(recipes.findByName(name)!.directions, isNot(contains('Boil.')));
  });

  testWidgets('a new recipe can be edited and deleted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-recipe')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('recipe-name')), 'saved toast');
    await tester.enterText(find.byKey(const ValueKey('recipe-tags')), 'side dish');
    await tester.enterText(find.byKey(const ValueKey('recipe-servings')), '2');
    await tester.enterText(
      find.byKey(const ValueKey('recipe-ingredients')),
      '1 cup whole wheat flour',
    );
    await tester.enterText(find.byKey(const ValueKey('recipe-directions')), 'Stir.');
    await tester.tap(find.byKey(const ValueKey('save-recipe')));
    await tester.pumpAndSettle();

    final toast = recipes.findByName('saved toast')!;
    expect(toast.isPriced, isTrue);
    expect(toast.lines.single.food!.name, 'whole wheat flour');
    expect(toast.servings, 2);
    final tile = find.byKey(const ValueKey('recipe-saved toast'));
    await tester.scrollUntilVisible(tile, 400, scrollable: _listScroll);
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text(toast.servingPrice.toString())),
      findsOneWidget,
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Stir.'), findsOneWidget);
    final recipeBar = find.widgetWithText(AppBar, 'Saved Toast');
    expect(
      find.descendant(of: recipeBar, matching: find.byKey(const ValueKey('edit-recipe'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: recipeBar, matching: find.byKey(const ValueKey('delete-recipe'))),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('recipe-detail')),
        matching: find.byKey(const ValueKey('edit-recipe')),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('edit-recipe')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('recipe-directions')), 'Toast the bread.');
    await tester.tap(find.byKey(const ValueKey('save-recipe')));
    await tester.pumpAndSettle();
    expect(find.text('Toast the bread.'), findsOneWidget);
    expect(find.text('Stir.'), findsNothing);
    expect(recipes.findByName('saved toast')!.directions, ['Toast the bread.']);

    await tester.tap(find.byKey(const ValueKey('delete-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await tester.pumpAndSettle();

    expect(recipes.findByName('saved toast'), isNull);
    expect(find.byKey(const ValueKey('recipe-saved toast')), findsNothing);
    expect(find.byKey(const ValueKey('recipe-list')), findsOneWidget);
  });

  testWidgets('changing an ingredient price updates the recipe list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final before = recipes.findByName('cornbread')!;
    final previousPrice = before.servingPrice.toString();
    final calories = before.totalNutrition.calories;

    await tester.tap(find.byKey(const ValueKey('open-ingredients')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ingredient-search')), 'whole wheat flour');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ingredient-whole wheat flour')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ingredient-price')), '0');
    await tester.tap(find.byKey(const ValueKey('save-ingredient')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    final updated = recipes.findByName('cornbread')!;
    expect(updated.servingPrice.toString(), isNot(previousPrice));
    expect(updated.totalNutrition.calories, closeTo(calories, 1e-6));
    expect(ingredients.findByName('whole wheat flour')!.totalPrice.dollars, 0);

    await tester.enterText(find.byKey(const ValueKey('recipe-search')), 'cornbread');
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('recipe-cornbread'));
    await tester.scrollUntilVisible(tile, 400, scrollable: _listScroll);
    expect(
      find.descendant(of: tile, matching: find.text(updated.servingPrice.toString())),
      findsOneWidget,
    );
    expect(find.descendant(of: tile, matching: find.text(previousPrice)), findsNothing);
  });
}

Ingredient _oatMilk({required String price}) {
  return Ingredient.fromEditor(
    name: 'test oat milk',
    servingSize: '1 cup',
    servings: '4',
    price: price,
    calories: '120',
    nutrients: const [(name: 'Protein', amount: '8 g')],
  );
}

Recipe _latte() {
  return Recipe.fromEditor(
    name: 'oat latte',
    tags: 'drink',
    servings: '2',
    calculatesNutrition: true,
    ingredientText: '2 cups test oat milk',
    directions: const ['Stir.'],
  );
}

final _listScroll = find.descendant(
  of: find.byKey(const ValueKey('recipe-list')),
  matching: find.byType(Scrollable),
);
