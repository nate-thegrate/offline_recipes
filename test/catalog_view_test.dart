import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog.dart';
import 'package:offline_recipes/catalog_view.dart';
import 'package:offline_recipes/main.dart';
import 'package:offline_recipes/nutrition_label.dart';

void main() {
  setUpAll(() async {
    await loadCatalog();
  });

  setUp(() {
    meal.value = null;
    query.value = '';
    selected.value = null;
  });

  Future<void> openRecipe(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const ValueKey('recipe-search')), name);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('recipe-$name')));
    await tester.pumpAndSettle();
  }

  testWidgets('a priced recipe shows its price, and an unpriced one does not', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await openRecipe(tester, 'ice cream');
    final iceCream = recipes['ice cream'];
    final detail = find.byKey(const ValueKey('recipe-detail'));
    expect(find.text('Ice Cream'), findsOneWidget);
    expect(
      find.descendant(of: detail, matching: find.text(iceCream.servingPrice.toString())),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text(iceCream.totalPrice.toString())),
      findsOneWidget,
    );
    expect(find.text('Nutrition Facts'), findsOneWidget);
    expect(find.text('Percent of a 2000 Cal diet'), findsNothing);
    final label = NutritionLabel(iceCream);
    expect(find.descendant(of: detail, matching: find.text(label.servingCalories)), findsOneWidget);
    expect(find.descendant(of: detail, matching: find.text(label.recipeCalories)), findsOneWidget);
    final detailScroll = find.descendant(of: detail, matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('2 cups soy milk'), 300, scrollable: detailScroll);
    expect(find.text('2 cups soy milk'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Warm the milk'),
      300,
      scrollable: detailScroll,
    );
    expect(find.textContaining('Warm the milk'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openRecipe(tester, 'guacamole');
    expect(find.text('3 avocados', skipOffstage: false), findsOneWidget);
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

  testWidgets('directions drop markup and keep the words', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await openRecipe(tester, 'aebleskivers');
    final detailScroll = find.descendant(
      of: find.byKey(const ValueKey('recipe-detail')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.textContaining('except for the oil'),
      300,
      scrollable: detailScroll,
    );
    expect(find.textContaining('except for the oil'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openRecipe(tester, 'crepes');
    final crepeScroll = find.descendant(
      of: find.byKey(const ValueKey('recipe-detail')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.textContaining('how to cook crepes'),
      300,
      scrollable: crepeScroll,
    );
    expect(find.textContaining('how to cook crepes'), findsOneWidget);
    expect(find.textContaining('google.com'), findsNothing);
  });

  testWidgets('meal filters hide recipes from other meals', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('meal-drink')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('recipe-hot cocoa')), findsOneWidget);
    expect(find.byKey(const ValueKey('recipe-smoothie')), findsOneWidget);
    expect(find.byKey(const ValueKey('recipe-ice cream')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('meal-all')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('recipe-search')), 'bagel');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('recipe-bagels')), findsOneWidget);
    expect(find.byKey(const ValueKey('recipe-chili')), findsNothing);
  });

  testWidgets('selecting a recipe highlights that row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    ListTile tile(String name) {
      return tester.widget<ListTile>(
        find.descendant(of: find.byKey(ValueKey('recipe-$name')), matching: find.byType(ListTile)),
      );
    }

    await tester.tap(find.byKey(const ValueKey('recipe-cornbread')));
    await tester.pump();

    expect(tile('cornbread').selected, isTrue);
    expect(tile('popcorn').selected, isFalse);

    await tester.tap(find.byKey(const ValueKey('recipe-popcorn')));
    await tester.pump();

    expect(tile('cornbread').selected, isFalse);
    expect(tile('popcorn').selected, isTrue);
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
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('recipe-list')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    expect(position.pixels, greaterThan(0));
    expect(appBarMaterial().color, resting);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide window keeps the list beside the recipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await openRecipe(tester, 'red velvet cake');

    expect(find.byKey(const ValueKey('recipe-list')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Icing'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('recipe-detail')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Icing'), findsOneWidget);
    expect(find.text('16 oz plant-based cream cheese'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone-sized window can scroll a priced recipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    await openRecipe(tester, 'ice cream');
    await tester.scrollUntilVisible(
      find.text('Directions'),
      400,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('recipe-detail')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Directions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
