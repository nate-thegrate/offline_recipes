import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog.dart';
import 'package:offline_recipes/catalog_view.dart';
import 'package:offline_recipes/main.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCatalog);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await loadSettings();
    debugResetSettings();
    selectedTags.clear();
    query.value = '';
    selected.value = null;
  });

  test('ingredient units keep the written amount', () {
    expect(
      displayIngredient('1 1/2 tablespoon baking powder', .full),
      '1 1/2 tablespoons baking powder',
    );
    expect(displayIngredient('1 tablespoon oil', .full), '1 tablespoon oil');
    expect(displayIngredient('1/2 cup oil', .full), '1/2 cup oil');
    expect(displayIngredient('1/2 teaspoon salt', .short), '1/2 tsp salt');
    expect(displayIngredient('2 cups vegetable broth', .short), '2 cups vegetable broth');
    expect(
      displayIngredient('1 1/2 tablespoon baking powder', .superShort),
      '1 1/2 T baking powder',
    );
    expect(displayIngredient('1 teaspoon salt', .superShort), '1 t salt');
    expect(
      displayIngredient('8 oz beans (most cans are about 16 oz)', .full),
      '8 ounces beans (most cans are about 16 oz)',
    );
    expect(
      displayIngredient('salt & black pepper to taste', .superShort),
      'salt & black pepper to taste',
    );
  });

  test('hue seeds are fully saturated', () {
    for (final hue in [0.0, defaultHue, 180.0, 360.0]) {
      final hsv = HSVColor.fromColor(colorForHue(hue));
      expect(hsv.saturation, 1, reason: 'hue $hue');
      expect(hsv.value, 1, reason: 'hue $hue');
    }
    expect(colorForHue(0).toARGB32(), colorForHue(360).toARGB32());
  });

  testWidgets('settings leave the open recipe, search, and tag in place', (tester) async {
    await _size(tester, const Size(1200, 800));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final recipe = recipes.firstWhere((recipe) => recipe.tags.isNotEmpty);
    final tagName = recipe.tags.first;
    await tester.tap(find.byKey(ValueKey('tag-$tagName')));
    await tester.pumpAndSettle();
    await _openRecipe(tester, recipe);
    expect(_tile(tester, recipe.name).selected, isTrue);

    await _openSettings(tester);
    expect(selected.value, recipe);
    expect(selectedTags.value, {tagName});
    expect(query.value, recipe.name);

    await _closeSettings(tester);
    expect(_tile(tester, recipe.name).selected, isTrue);
    expect(find.text(displayIngredient(recipe.lines.first.text, .full)), findsWidgets);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('recipe-search'))).controller!.text,
      recipe.name,
    );
    expect(tester.widget<FilterChip>(find.byKey(ValueKey('tag-$tagName'))).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme mode follows the choice and the platform', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _size(tester, const Size(400, 900));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    Brightness brightness() => Theme.of(tester.element(find.byType(CatalogPage))).brightness;
    expect(brightness(), Brightness.light);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.system);

    await _openSettings(tester);
    await _choose(tester, 'theme-mode', 'Dark');
    expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness, Brightness.dark);

    await _choose(tester, 'theme-mode', 'Light');
    expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness, Brightness.light);

    await _choose(tester, 'theme-mode', 'System');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness, Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hue becomes the app theme', (tester) async {
    await _size(tester, const Size(400, 900));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    final before = Theme.of(tester.element(find.byType(CatalogPage))).colorScheme.primary;

    await _openSettings(tester);
    final slider = find.byKey(const ValueKey('color-hue'));
    await tester.tap(slider);
    await tester.pumpAndSettle();
    final tapped = colorSchemeHue.value;
    expect(tapped, closeTo(180, 1));
    expect(find.text('${tapped.round()}°'), findsOneWidget);

    await tester.drag(slider, const Offset(48, 0));
    await tester.pumpAndSettle();

    final hue = colorSchemeHue.value;
    expect(hue, greaterThan(tapped + 5));
    final context = tester.element(find.byType(SettingsPage));
    final scheme = Theme.of(context).colorScheme;
    expect(scheme.primary, isNot(before));
    expect(
      scheme.primary,
      ColorScheme.fromSeed(seedColor: colorForHue(hue), brightness: scheme.brightness).primary,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.colorScheme.primary,
      scheme.primary,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hue drag changes the theme before it is saved', (tester) async {
    await _size(tester, const Size(400, 900));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    await _openSettings(tester);

    final start = colorSchemeHue.value;
    final slider = find.byKey(const ValueKey('color-hue'));
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    final shown = tester.widget<Slider>(slider).value;
    expect(shown, greaterThan(start + 5));
    expect(colorSchemeHue.value, start);
    final context = tester.element(find.byType(SettingsPage));
    final scheme = Theme.of(context).colorScheme;
    expect(
      scheme.primary,
      ColorScheme.fromSeed(seedColor: colorForHue(shown), brightness: scheme.brightness).primary,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(colorSchemeHue.value, tester.widget<Slider>(slider).value);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unit names rewrite a recipe line and keep its check', (tester) async {
    await _size(tester, const Size(400, 800));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    const original = '1 1/2 tablespoon baking powder';
    final recipe = recipes.firstWhere(
      (recipe) => recipe.lines.any((line) => line.text == original),
    );
    await _openRecipe(tester, recipe);
    await tester.scrollUntilVisible(
      find.text(displayIngredient(original, .full)),
      300,
      scrollable: _detailScroll,
    );
    await tester.pumpAndSettle();

    final full = displayIngredient(original, .full);
    await tester.tap(find.text(full));
    await tester.pumpAndSettle();
    expect(_checkbox(tester, full).value, isTrue);

    await _openSettings(tester);
    await _choose(tester, 'unit-names', 'Tiny');
    await _closeSettings(tester);

    final tiny = displayIngredient(original, .superShort);
    expect(find.text(tiny), findsOneWidget);
    expect(find.text(full), findsNothing);
    expect(_checkbox(tester, tiny).value, isTrue);

    await _openSettings(tester);
    await _choose(tester, 'unit-names', 'Short');
    await _closeSettings(tester);
    final abbreviated = displayIngredient(original, .short);
    expect(find.text(abbreviated), findsOneWidget);
    expect(_checkbox(tester, abbreviated).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the recipe list can show a serving price, a recipe price, or nothing', (
    tester,
  ) async {
    await _size(tester, const Size(400, 800));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final recipe = _pricedServings();
    await tester.enterText(find.byKey(const ValueKey('recipe-search')), recipe.name);
    await tester.pumpAndSettle();
    final tile = find.byKey(ValueKey('recipe-${recipe.name}'));

    expect(recipe.totalPrice.dollars, isNot(recipe.servingPrice.dollars));
    expect(_inTile(tile, recipe.servingPrice.toString()), findsOneWidget);
    expect(_inTile(tile, recipe.totalPrice.toString()), findsNothing);

    await _openSettings(tester);
    await _choose(tester, 'list-price', 'Recipe');
    await _closeSettings(tester);
    expect(_inTile(tile, recipe.totalPrice.toString()), findsOneWidget);
    expect(_inTile(tile, recipe.servingPrice.toString()), findsNothing);

    await _openSettings(tester);
    await _choose(tester, 'list-price', 'Hidden');
    await _closeSettings(tester);
    expect(_inTile(tile, recipe.totalPrice.toString()), findsNothing);
    expect(_inTile(tile, recipe.servingPrice.toString()), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text size scales the list and the nutrition label stays fixed', (tester) async {
    await _size(tester, const Size(1100, 800));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final recipe = _pricedServings();
    await tester.enterText(find.byKey(const ValueKey('recipe-search')), recipe.name);
    await tester.pumpAndSettle();
    final title = find.text(titleCase(recipe.name));
    final before = tester.getSize(title).height;

    await tester.tap(find.byKey(ValueKey('recipe-${recipe.name}')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Nutrition Facts'), 400, scrollable: _detailScroll);
    expect(
      MediaQuery.textScalerOf(tester.element(find.byKey(const ValueKey('nutrition-facts'))))
          .scale(12),
      12,
    );

    await _openSettings(tester);
    await _choose(tester, 'text-size', 'Large');
    await _closeSettings(tester);

    expect(tester.getSize(title).height, greaterThan(before));
    await tester.scrollUntilVisible(find.text('Nutrition Facts'), 400, scrollable: _detailScroll);
    expect(
      MediaQuery.textScalerOf(tester.element(find.byKey(const ValueKey('nutrition-facts'))))
          .scale(12),
      12,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('nutrition facts can be hidden without hiding the price', (tester) async {
    await _size(tester, const Size(1100, 800));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final recipe = _pricedServings();
    await _openRecipe(tester, recipe);
    await tester.scrollUntilVisible(find.text('Nutrition Facts'), 400, scrollable: _detailScroll);
    expect(_inDetail('Nutrition Facts'), findsOneWidget);

    await _openSettings(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('show-nutrition')),
      200,
      scrollable: _settingsScroll,
    );
    await tester.tap(find.byKey(const ValueKey('show-nutrition')));
    await tester.pumpAndSettle();
    await _closeSettings(tester);

    expect(_inDetail('Nutrition Facts'), findsNothing);
    expect(_inDetail(recipe.totalPrice.toString()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chosen theme is still selected after a restart', (tester) async {
    await loadSettings();
    await _size(tester, const Size(400, 1400));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await _choose(tester, 'theme-mode', 'Dark');
    await tester.tap(find.byKey(const ValueKey('color-hue')));
    await tester.pumpAndSettle();
    final hue = colorSchemeHue.value;
    expect(hue, closeTo(180, 1));
    await _choose(tester, 'unit-names', 'Tiny');
    await _choose(tester, 'list-price', 'Hidden');
    await _choose(tester, 'text-size', 'Large');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('show-nutrition')),
      200,
      scrollable: _settingsScroll,
    );
    await tester.tap(find.byKey(const ValueKey('show-nutrition')));
    await tester.pumpAndSettle();

    debugResetSettings();
    await loadSettings();
    await tester.pumpAndSettle();

    final scheme = Theme.of(tester.element(find.byType(SettingsPage))).colorScheme;
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    expect(scheme.brightness, Brightness.dark);
    expect(colorSchemeHue.value, hue);
    expect(
      tester.widget<SegmentedButton<UnitNames>>(find.byKey(const ValueKey('unit-names'))).selected,
      {UnitNames.superShort},
    );
    expect(
      tester.widget<SegmentedButton<ListPrice>>(find.byKey(const ValueKey('list-price'))).selected,
      {ListPrice.hidden},
    );
    expect(
      tester.widget<SegmentedButton<TextSize>>(find.byKey(const ValueKey('text-size'))).selected,
      {TextSize.large},
    );
    expect(
      tester.widget<SwitchListTile>(find.byKey(const ValueKey('show-nutrition'))).value,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _size(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings').hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _closeSettings(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.widgetWithText(AppBar, 'Settings'), matching: find.byTooltip('Back')),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String group, String label) async {
  final finder = find.descendant(of: find.byKey(ValueKey(group)), matching: find.text(label));
  await tester.scrollUntilVisible(finder, 200, scrollable: _settingsScroll);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Recipe _pricedServings() {
  for (final recipe in recipes) {
    if (!recipe.isPriced || !recipe.servingsSpecified || recipe.servings == 1) continue;
    return recipe;
  }
  fail('Expected a priced recipe with several servings');
}

ListTile _tile(WidgetTester tester, String name) {
  return tester.widget<ListTile>(
    find.descendant(of: find.byKey(ValueKey('recipe-$name')), matching: find.byType(ListTile)),
  );
}

Checkbox _checkbox(WidgetTester tester, String text) {
  final tile = find.ancestor(of: find.text(text), matching: find.byType(CheckboxListTile));
  return tester.widget<Checkbox>(find.descendant(of: tile, matching: find.byType(Checkbox)));
}

Finder _inTile(Finder tile, String text) {
  return find.descendant(of: tile, matching: find.text(text));
}

Finder _inDetail(String text) {
  return find.descendant(
    of: find.byKey(const ValueKey('recipe-detail')),
    matching: find.text(text),
  );
}

final _settingsScroll = find.descendant(
  of: find.byType(SettingsPage),
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

final _listScroll = find.descendant(
  of: find.byKey(const ValueKey('recipe-list')),
  matching: find.byType(Scrollable),
);
