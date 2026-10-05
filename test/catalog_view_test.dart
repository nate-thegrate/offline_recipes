import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog.dart';
import 'package:offline_recipes/catalog_view.dart';
import 'package:offline_recipes/main.dart';

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
    await tester.pumpWidget(const MainApp());
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
    expect(
      find.descendant(
        of: detail,
        matching: find.text(formatCalories(iceCream.servingNutrition.calories)),
      ),
      findsOneWidget,
    );
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
    await openRecipe(tester, 'cornbread');
    expect(find.text('1 cup whole wheat flour', skipOffstage: false), findsOneWidget);
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
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await openRecipe(tester, 'aebleskivers');
    expect(find.textContaining('except for the oil'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openRecipe(tester, 'crepes');
    expect(find.textContaining('how to cook crepes'), findsOneWidget);
    expect(find.textContaining('google.com'), findsNothing);
  });

  testWidgets('meal filters hide recipes from other meals', (tester) async {
    await tester.pumpWidget(const MainApp());
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

  testWidgets('a wide window keeps the list beside the recipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await openRecipe(tester, 'red velvet cake');

    expect(find.byKey(const ValueKey('recipe-list')), findsOneWidget);
    expect(find.text('Icing'), findsOneWidget);
    expect(find.text('16 oz plant-based cream cheese'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone-sized window can scroll a priced recipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MainApp());
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
