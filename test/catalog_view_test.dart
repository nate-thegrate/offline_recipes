import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog.dart';
import 'package:offline_recipes/catalog_view.dart';
import 'package:offline_recipes/food.dart';
import 'package:offline_recipes/main.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/nutrition_label.dart';

void main() {
  setUpAll(loadCatalog);

  setUp(() {
    meal.value = null;
    query.value = '';
    selected.value = null;
  });

  testWidgets('a priced recipe shows its price and nutrition, and an unpriced one does not', (
    tester,
  ) async {
    final ingredient = Ingredient(
      name: 'broth',
      servingSize: const Measure(1, Unit.cup),
      servings: 4,
      totalPrice: const Price(8),
      servingNutrition: const NutritionFacts(calories: 40, grams: {'Total Fat': 1}),
    );
    final used = ingredient.used(const Measure(1, Unit.cup))!;
    final priced = Recipe(
      name: 'test soup',
      meals: const ['soup'],
      servings: 2,
      servingsSpecified: true,
      calculatesNutrition: true,
      lines: [
        RecipeLine('1 cup broth', food: used, group: 'soup'),
        RecipeLine('1 cup extra (optional)', food: used, optional: true),
      ],
      directions: const [
        'Stir **except for the oil**.',
        'See [how to cook crepes](https://google.com/search).',
        'first line.<br>second line',
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecipeDetail(recipe: priced, showTitle: true)),
      ),
    );
    await tester.pumpAndSettle();

    final detail = find.byKey(const ValueKey('recipe-detail'));
    expect(find.text('Test Soup'), findsOneWidget);
    expect(
      find.descendant(of: detail, matching: find.text(priced.servingPrice.toString())),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text(priced.totalPrice.toString())),
      findsOneWidget,
    );
    expect(find.text('Nutrition Facts'), findsOneWidget);
    expect(find.text('Percent of a 2000 Cal diet'), findsNothing);
    final label = NutritionLabel(priced);
    expect(find.descendant(of: detail, matching: find.text(label.servingCalories)), findsOneWidget);
    expect(find.descendant(of: detail, matching: find.text(label.recipeCalories)), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Soup'), 400, scrollable: _detailScroll);
    expect(find.text('Soup'), findsOneWidget);
    expect(find.text('1 cup broth'), findsOneWidget);
    expect(find.text('1 cup extra (optional)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('except for the oil'),
      400,
      scrollable: _detailScroll,
    );
    expect(find.textContaining('except for the oil'), findsOneWidget);
    final rich = tester.widget<Text>(find.textContaining('except for the oil'));
    final bold = (rich.textSpan! as TextSpan).children!.whereType<TextSpan>().singleWhere(
      (child) => child.text == 'except for the oil',
    );
    expect(bold.style?.fontWeight, FontWeight.w600);
    await tester.scrollUntilVisible(
      find.textContaining('how to cook crepes'),
      400,
      scrollable: _detailScroll,
    );
    expect(find.textContaining('how to cook crepes'), findsOneWidget);
    expect(find.textContaining('google.com'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('first line.'),
      400,
      scrollable: _detailScroll,
    );
    expect(find.textContaining('first line.\nsecond line'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);

    final unpriced = Recipe(
      name: 'test salad',
      meals: const ['side dish'],
      servings: 1,
      servingsSpecified: true,
      calculatesNutrition: false,
      lines: [RecipeLine('1 cup broth', food: used)],
      directions: const ['Toss.'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecipeDetail(recipe: unpriced, showTitle: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Salad'), findsOneWidget);
    expect(find.text('Nutrition Facts'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('recipe-detail')),
        matching: find.textContaining(r'$'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal filters and search show the recipes that match', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final mealName = _selectiveMeal();
    await tester.tap(find.byKey(ValueKey('meal-$mealName')));
    await tester.pumpAndSettle();

    final listed = recipes.where((recipe) => recipe.matches(mealName, '')).first;
    expect(find.byKey(ValueKey('recipe-${listed.name}')), findsOneWidget);
    for (final recipe in recipes) {
      if (recipe.matches(mealName, '')) continue;
      expect(find.byKey(ValueKey('recipe-${recipe.name}')), findsNothing, reason: recipe.name);
    }

    await tester.tap(find.byKey(const ValueKey('meal-all')));
    await tester.pumpAndSettle();
    final shown = recipes.first;
    await tester.enterText(find.byKey(const ValueKey('recipe-search')), shown.name);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(ValueKey('recipe-${shown.name}')),
      400,
      scrollable: _listScroll,
    );
    expect(find.byKey(ValueKey('recipe-${shown.name}')), findsOneWidget);
    for (final recipe in recipes) {
      if (recipe.matches(null, shown.name)) continue;
      expect(find.byKey(ValueKey('recipe-${recipe.name}')), findsNothing, reason: recipe.name);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a recipe highlights that row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final listed = recipes.toList();
    final first = listed.first;
    await tester.tap(find.byKey(ValueKey('recipe-${first.name}')));
    await tester.pump();

    expect(_tile(tester, first.name).selected, isTrue);
    if (listed.length > 1) {
      final second = listed[1];
      expect(_tile(tester, second.name).selected, isFalse);

      await tester.tap(find.byKey(ValueKey('recipe-${second.name}')));
      await tester.pump();

      expect(_tile(tester, first.name).selected, isFalse);
      expect(_tile(tester, second.name).selected, isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app bar keeps its color while the list scrolls', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    Material appBarMaterial() {
      return tester.widget<Material>(
        find.descendant(of: find.byType(AppBar), matching: find.byType(Material)).first,
      );
    }

    final resting = appBarMaterial().color;
    await tester.drag(find.byKey(const ValueKey('recipe-list')), const Offset(0, -400));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(_listScroll).position;

    if (position.maxScrollExtent > 0) {
      expect(position.pixels, greaterThan(0));
    }
    expect(appBarMaterial().color, resting);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide window keeps the list beside the recipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final recipe = recipes.firstWhere(
      (recipe) => recipe.lines.any((line) => line.group != null),
      orElse: () => recipes.first,
    );
    await _openRecipe(tester, recipe);

    expect(find.byKey(const ValueKey('recipe-list')), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    final line = recipe.lines.firstWhere(
      (line) => line.group != null,
      orElse: () => recipe.lines.first,
    );
    final detailScroll = _detailScroll;
    await tester.scrollUntilVisible(find.text(line.text), 300, scrollable: detailScroll);
    expect(find.text(line.text), findsWidgets);
    final group = line.group;
    if (group != null) {
      expect(find.text(titleCase(group)), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone-sized window opens the recipe on its own', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final recipe = recipes.first;
    await _openRecipe(tester, recipe);
    await tester.scrollUntilVisible(find.text('Directions'), 400, scrollable: _detailScroll);
    await tester.pumpAndSettle();

    expect(find.text(titleCase(recipe.name)), findsOneWidget);
    expect(find.text('Directions'), findsWidgets);
    expect(find.byKey(const ValueKey('recipe-list')), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _selectiveMeal() {
  for (final name in meals) {
    if (recipes.any((recipe) => !recipe.meals.contains(name))) return name;
  }
  return meals.first;
}

ListTile _tile(WidgetTester tester, String name) {
  return tester.widget<ListTile>(
    find.descendant(of: find.byKey(ValueKey('recipe-$name')), matching: find.byType(ListTile)),
  );
}

final _listScroll = find.descendant(
  of: find.byKey(const ValueKey('recipe-list')),
  matching: find.byType(Scrollable),
);

final _detailScroll = find.descendant(
  of: find.byKey(const ValueKey('recipe-detail')),
  matching: find.byType(Scrollable),
);

Future<void> _openRecipe(WidgetTester tester, Recipe recipe) async {
  await tester.enterText(find.byKey(const ValueKey('recipe-search')), recipe.name);
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('recipe-${recipe.name}'));
  await tester.scrollUntilVisible(tile, 400, scrollable: _listScroll);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
