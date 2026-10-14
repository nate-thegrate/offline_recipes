import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog/catalog.dart';
import 'package:offline_recipes/catalog_view/catalog_view.dart';
import 'package:offline_recipes/main.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCatalog);

  testWidgets('stored settings are applied at startup', (tester) async {
    SharedPreferences.setMockInitialValues({
      'themeMode': 'dark',
      'colorSchemeHue': '200',
      'unitNames': 'superShort',
      'listPrice': 'hidden',
      'textSize': 'large',
      'showNutrition': 'false',
    });
    await loadSettings();
    expect(colorSchemeHue.value, 200);
    expect(colorSchemeSeed.value.toARGB32(), colorForHue(200).toARGB32());

    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    final scheme = Theme.of(tester.element(find.byType(CatalogPage))).colorScheme;
    expect(scheme.brightness, Brightness.dark);
    expect(
      scheme.primary,
      ColorScheme.fromSeed(seedColor: colorForHue(200), brightness: .dark).primary,
    );

    await tester.tap(find.byTooltip('Settings').hitTestable());
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byKey(const ValueKey('color-hue'))).value, 200);
    expect(
      tester.widget<SegmentedButton<ThemeMode>>(find.byKey(const ValueKey('theme-mode'))).selected,
      {ThemeMode.dark},
    );
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('show-nutrition')),
      200,
      scrollable: find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      tester.widget<SwitchListTile>(find.byKey(const ValueKey('show-nutrition'))).value,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
