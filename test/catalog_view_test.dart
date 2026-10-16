import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog/catalog.dart';
import 'package:offline_recipes/catalog_view/catalog_view.dart';
import 'package:offline_recipes/food.dart';
import 'package:offline_recipes/main.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(loadCatalog);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await loadSettings();
    debugResetSettings();
    selectedTags.clear();
    recipes.controller.clear();
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
      tags: const ['soup'],
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
    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Soup'), findsOneWidget);
    expect(find.text('1 cup broth'), findsOneWidget);
    expect(find.text('1 cup extra (optional)'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(priced.lines.length));
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).map((box) => box.value),
      everyElement(isFalse),
    );

    await tester.tap(find.text('1 cup broth'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isFalse);

    await tester.tap(find.text('1 cup broth'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).map((box) => box.value),
      everyElement(isFalse),
    );

    await tester.tap(find.text('1 cup broth'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    final checkedColor = _ingredientColor(tester, '1 cup broth');
    final plainColor = _ingredientColor(tester, '1 cup extra (optional)');
    expect(checkedColor.a, lessThan(plainColor.a));
    expect(checkedColor.withValues(alpha: plainColor.a), plainColor);

    await tester.scrollUntilVisible(find.text('Nutrition Facts'), 400, scrollable: _detailScroll);
    expect(
      tester.getTopLeft(find.text('Directions')).dy,
      lessThan(tester.getTopLeft(find.text(priced.servingPrice.toString())).dy),
    );
    expect(
      tester.getTopLeft(find.text(priced.totalPrice.toString())).dy,
      lessThan(tester.getTopLeft(find.text('Nutrition Facts')).dy),
    );
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
      tags: const ['side dish'],
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
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(_ingredientColor(tester, '1 cup broth'), plainColor);
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

  testWidgets('a checked ingredient stays checked after scrolling the recipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final recipe = Recipe(
      name: 'long stew',
      tags: const ['soup'],
      servings: 4,
      servingsSpecified: true,
      calculatesNutrition: false,
      lines: [for (var i = 0; i < 40; i++) RecipeLine('ingredient $i')],
      directions: const ['Simmer until thick.'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecipeDetail(recipe: recipe, showTitle: true)),
      ),
    );
    await tester.pumpAndSettle();

    final top = find.byKey(const ValueKey('ingredient-0'));
    await tester.tap(find.descendant(of: top, matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Checkbox>(find.descendant(of: top, matching: find.byType(Checkbox))).value,
      isTrue,
    );

    final position = tester.state<ScrollableState>(_detailScroll).position;
    for (var i = 0; i < 8 && position.extentAfter > 0; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
    }
    expect(position.extentAfter, 0);
    expect(position.pixels, greaterThan(position.viewportDimension + 250));

    position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(
      tester.widget<Checkbox>(find.descendant(of: top, matching: find.byType(Checkbox))).value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag filters and search show the recipes that match', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<FilterChip>(find.byType(FilterChip)).map((chip) => chip.selected),
      everyElement(isFalse),
    );

    final tagName = _selectiveTag();
    await tester.tap(find.byKey(ValueKey('tag-$tagName')));
    await tester.pumpAndSettle();

    final listed = recipes.where((recipe) => recipe.matches([tagName], '')).first;
    expect(find.byKey(ValueKey('recipe-${listed.name}')), findsOneWidget);
    for (final recipe in recipes) {
      if (recipe.matches([tagName], '')) continue;
      expect(find.byKey(ValueKey('recipe-${recipe.name}')), findsNothing, reason: recipe.name);
    }

    final excluded = recipes.firstWhere((recipe) => !recipe.tags.contains(tagName));
    await tester.tap(find.byKey(ValueKey('tag-$tagName')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byKey(ValueKey('tag-$tagName'))).selected, isFalse);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('recipe-${excluded.name}')),
      400,
      scrollable: _listScroll,
    );
    expect(find.byKey(ValueKey('recipe-${excluded.name}')), findsOneWidget);

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
      if (recipe.matches(const [], shown.name)) continue;
      expect(find.byKey(ValueKey('recipe-${recipe.name}')), findsNothing, reason: recipe.name);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long press or shift-click keeps the other selected tags', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    Finder findRecipe(Recipe recipe) => find.byKey(ValueKey('recipe-${recipe.name}'));

    Future<void> tapWithKeyHeld(Finder finder, {LogicalKeyboardKey key = .shiftLeft}) async {
      await tester.sendKeyDownEvent(key);
      await tester.tap(finder, kind: .mouse);
      await tester.sendKeyUpEvent(key);
    }

    void expectSelected(Set<String> selected) {
      for (final name in tags) {
        expect(
          tester.widget<FilterChip>(find.byKey(ValueKey('tag-$name'))).selected,
          selected.contains(name),
          reason: name,
        );
      }
    }

    Future<void> expectListed(Recipe recipe) async {
      final tile = findRecipe(recipe);
      await tester.scrollUntilVisible(tile, 400, scrollable: _listScroll);
      expect(tile, findsOneWidget);
    }

    final (:first, :second, :both, :onlyFirst, :onlySecond) = _tagPair();
    final findFirst = find.byKey(ValueKey('tag-$first'));
    final findSecond = find.byKey(ValueKey('tag-$second'));

    await tester.tap(findFirst);
    await tester.pumpAndSettle();
    expectSelected({first});
    await expectListed(onlyFirst);
    expect(findRecipe(onlySecond), findsNothing);

    await tester.longPress(findSecond, kind: .mouse);
    await tester.pumpAndSettle();
    expectSelected({first, second});
    await expectListed(both);
    expect(findRecipe(onlyFirst), findsNothing);
    expect(findRecipe(onlySecond), findsNothing);

    await tester.longPress(findSecond);
    await tester.pumpAndSettle();
    expectSelected({first});
    await expectListed(onlyFirst);

    await tapWithKeyHeld(findSecond);
    await tester.pumpAndSettle();
    expectSelected({first, second});
    expect(findRecipe(onlyFirst), findsNothing);

    await tapWithKeyHeld(findFirst);
    await tester.pumpAndSettle();
    expectSelected({second});
    await expectListed(onlySecond);
    expect(findRecipe(onlyFirst), findsNothing);

    await tapWithKeyHeld(findFirst, key: .controlLeft);
    await tester.pumpAndSettle();
    expectSelected({first});
    expect(findRecipe(onlySecond), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a recipe highlights that row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(CatalogPage.wideLayoutWidth, 800));
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
    await tester.binding.setSurfaceSize(const Size(CatalogPage.wideLayoutWidth, 800));
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
      expect(find.text(group.titleCase), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow window opens the recipe on its own', (tester) async {
    await tester.binding.setSurfaceSize(const Size(CatalogPage.wideLayoutWidth - 1, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final recipe = recipes.first;
    await _openRecipe(tester, recipe);
    expect(find.text(recipe.name.titleCase), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Directions'), 400, scrollable: _detailScroll);
    await tester.pumpAndSettle();
    expect(find.text('Directions'), findsWidgets);
    final position = tester.state<ScrollableState>(_detailScroll).position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(find.text(recipe.name.titleCase), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-recipe')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-recipe')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-settings')), findsNothing);
    expect(find.byKey(const ValueKey('recipe-list')), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('a recipe subtitle names the tags on that recipe', () {
    const assigned = ['breakfast', 'dessert'];
    final recipe = Recipe(
      name: 'test toast',
      tags: assigned,
      servings: 2,
      servingsSpecified: true,
      calculatesNutrition: false,
      lines: const [],
      directions: const [],
    );
    final label = assigned.map((tag) => tag.titleCase).join(', ');
    final count = '${recipe.servings.plainNumber} servings';

    expect(recipe.subtitle, '$label · $count');
    expect(recipe.subtitleOmitting({assigned.first}), '${assigned.last.titleCase} · $count');
    expect(recipe.subtitleOmitting(assigned.toSet()), count);
    for (final tag in tags) {
      if (assigned.contains(tag)) continue;
      expect(recipe.subtitle, isNot(contains(tag.titleCase)));
    }
  });

  testWidgets('selected tags have no check mark and leave the list subtitle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(CatalogPage.wideLayoutWidth, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final recipe = recipes.firstWhere(
      (recipe) => recipe.tags.length > 1 && recipe.servingsSpecified,
    );
    final dropped = recipe.tags.first;
    await _reveal(tester, recipe);
    expect(_tileSubtitle(tester, recipe.name), recipe.subtitle);

    await tester.tap(find.byKey(ValueKey('tag-$dropped')));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<FilterChip>(find.byType(FilterChip)).map((chip) => chip.showCheckmark),
      everyElement(isFalse),
    );
    expect(tester.widget<FilterChip>(find.byKey(ValueKey('tag-$dropped'))).selected, isTrue);
    expect(_tileSubtitle(tester, recipe.name), recipe.subtitleOmitting(selectedTags.value));

    final detail = find.byKey(const ValueKey('recipe-detail'));
    expect(find.descendant(of: detail, matching: find.text(recipe.subtitle)), findsNothing);
    await tester.tap(find.byKey(ValueKey('recipe-${recipe.name}')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: detail, matching: find.text(recipe.subtitle)), findsOneWidget);
    expect(_tileSubtitle(tester, recipe.name), recipe.subtitleOmitting({dropped}));

    final lone = recipes.firstWhere(
      (candidate) =>
          candidate.tags.length == 1 &&
          candidate.tags.single == dropped &&
          !candidate.servingsSpecified,
    );
    await _reveal(tester, lone);
    expect(_tileSubtitle(tester, lone.name), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow catalog bar places the menu with the app bar actions', (tester) async {
    const narrow = Size(CatalogPage.wideLayoutWidth - 1, 800);
    await tester.binding.setSurfaceSize(narrow);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('recipe-search'));
    final menu = find.byKey(const ValueKey('more-actions'));
    expect(find.descendant(of: search, matching: menu), findsNothing);
    expect(find.byKey(const ValueKey('new-recipe')), findsNothing);
    expect(find.byKey(const ValueKey('open-ingredients')), findsNothing);
    expect(find.byKey(const ValueKey('open-settings')), findsNothing);

    final searchRect = tester.getRect(search);
    final menuRect = tester.getRect(menu);
    final bar = tester.getRect(find.byType(AppBar));
    expect(menuRect.left, greaterThanOrEqualTo(searchRect.right));
    expect(menuRect.right, lessThanOrEqualTo(bar.right));
    expect(searchRect.height, lessThanOrEqualTo(bar.height));
    expect(menuRect.height, lessThanOrEqualTo(bar.height));
    expect(menuRect.center.dy, closeTo(searchRect.center.dy, 0.5));

    const wide = Size(CatalogPage.wideLayoutWidth, 800);
    await tester.binding.setSurfaceSize(wide);
    await tester.pumpAndSettle();
    final action = tester.getRect(find.byKey(const ValueKey('open-settings')));
    final wideBar = tester.getRect(find.byType(AppBar));
    expect(find.byKey(const ValueKey('more-actions')), findsNothing);
    expect(menuRect.size, action.size);
    expect(bar.right - menuRect.right, closeTo(wideBar.right - action.right, 0.1));
    expect(menuRect.center.dy, closeTo(action.center.dy, 0.1));

    await tester.binding.setSurfaceSize(narrow);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('more-actions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-recipe')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-ingredients')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-settings')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

({String first, String second, Recipe both, Recipe onlyFirst, Recipe onlySecond}) _tagPair() {
  for (final first in tags) {
    for (final second in tags) {
      if (first == second) continue;
      Recipe? both;
      Recipe? onlyFirst;
      Recipe? onlySecond;
      for (final recipe in recipes) {
        final hasFirst = recipe.tags.contains(first);
        final hasSecond = recipe.tags.contains(second);
        if (hasFirst && hasSecond) {
          both ??= recipe;
        } else if (hasFirst) {
          onlyFirst ??= recipe;
        } else if (hasSecond) {
          onlySecond ??= recipe;
        }
      }
      if (both != null && onlyFirst != null && onlySecond != null) {
        return (
          first: first,
          second: second,
          both: both,
          onlyFirst: onlyFirst,
          onlySecond: onlySecond,
        );
      }
    }
  }
  fail('Expected two tags with a shared recipe and recipes unique to each');
}

String _selectiveTag() {
  for (final name in tags) {
    if (recipes.any((recipe) => !recipe.tags.contains(name))) return name;
  }
  return tags.first;
}

Color _ingredientColor(WidgetTester tester, String text) {
  final finder = find.text(text);
  final style = tester.widget<Text>(finder).style;
  return style?.color ?? DefaultTextStyle.of(tester.element(finder)).style.color!;
}

ListTile _tile(WidgetTester tester, String name) {
  return tester.widget<ListTile>(
    find.descendant(of: find.byKey(ValueKey('recipe-$name')), matching: find.byType(ListTile)),
  );
}

String? _tileSubtitle(WidgetTester tester, String name) {
  final subtitle = _tile(tester, name).subtitle;
  if (subtitle is! Text) return null;
  return subtitle.data;
}

Future<void> _reveal(WidgetTester tester, Recipe recipe) async {
  await tester.enterText(find.byKey(const ValueKey('recipe-search')), recipe.name);
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('recipe-${recipe.name}'));
  await tester.scrollUntilVisible(tile, 400, scrollable: _listScroll);
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
