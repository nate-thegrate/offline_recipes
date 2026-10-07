import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog.dart';
import 'package:offline_recipes/food.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/nutrition_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadCatalog);

  test('calories use 5 and 10 increments', () {
    expect(labelCalories(0), '0');
    expect(labelCalories(4.9), '0');
    expect(labelCalories(5), '5');
    expect(labelCalories(7), '5');
    expect(labelCalories(7.5), '10');
    expect(labelCalories(47), '45');
    expect(labelCalories(50), '50');
    expect(labelCalories(52), '50');
    expect(labelCalories(55), '60');
    expect(labelCalories(163), '160');
  });

  test('amounts keep a tenth below ten', () {
    expect(labelAmount(1.25), '1.3');
    expect(labelAmount(1.75), '1.8');
    expect(labelAmount(0.25), '0.3');
    expect(labelAmount(2), '2.0');
    expect(labelAmount(0), '0');
    expect(labelAmount(10), '10');
    expect(labelAmount(14.5), '15');
    expect(labelAmount(15.5), '16');
    expect(Measure.parse('1 g').percentOf(Measure.parse('8 g')), '13%');
    expect(Measure.parse('12.5 g').percentOf(Measure.parse('100 g')), '13%');
    expect(Measure.parse('13.5 g').percentOf(Measure.parse('100 g')), '14%');
  });

  test('label calories match the priced recipe', () {
    for (final recipe in recipes.where((recipe) => recipe.isPriced)) {
      final table = NutritionLabel(recipe);
      expect(
        table.recipeCalories,
        labelCalories(recipe.totalNutrition.calories),
        reason: recipe.name,
      );
      expect(
        table.servingCalories,
        labelCalories(recipe.servingNutrition.calories),
        reason: recipe.name,
      );
    }
  });

  testWidgets('a label divides the measured foods into serving and recipe cells', (tester) async {
    final (:recipe, :vitamin) = _labeledSample();
    final label = NutritionLabel(recipe);
    final lines = await _labelRows(tester, label.macros);

    _expectMeasured(lines, 'Total Fat', '10 g', recipe.servings);
    _expectMeasured(lines, 'Saturated Fat', '1 g', recipe.servings);
    _expectMeasured(lines, 'Protein', '1 g', recipe.servings);

    final fat = lines.singleWhere((line) => line.name == 'Total Fat');
    final protein = lines.singleWhere((line) => line.name == 'Protein');
    expect(
      lines.singleWhere((line) => line.name == 'Saturated Fat').nameInset,
      greaterThan(fat.nameInset),
    );
    expect(protein.height, greaterThan(fat.height));
    expect(protein.nameTop, fat.nameTop);

    final vitamins = await _labelRows(tester, label.vitamins);
    final vitaminLine = vitamins.singleWhere((line) => line.name == vitamin);
    final total = dailyValues[vitamin]!;
    final serving = total.perServing(recipe.servings);
    expect(vitaminLine.serving, [serving.percentOf(total)]);
    expect(vitaminLine.recipe, [total.percentOf(total)]);
    for (final line in vitamins) {
      expect(line.serving, hasLength(1), reason: line.name);
      expect(line.recipe, hasLength(1), reason: line.name);
      expect(line.serving.single, endsWith('%'), reason: line.name);
      expect(line.recipe.single, endsWith('%'), reason: line.name);
    }
  });

  testWidgets('the label paints the nutrition facts frame', (tester) async {
    final (:recipe, :vitamin) = _labeledSample();
    final label = NutritionLabel(recipe);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListView(children: [NutritionLabel(recipe)])),
      ),
    );

    expect(find.text('Nutrition Facts'), findsOneWidget);
    expect(find.text(label.yieldText), findsOneWidget);
    expect(label.yieldText, 'recipe yields 4 servings');
    expect(find.text('one serving'), findsOneWidget);
    expect(find.text('whole recipe'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);
    expect(find.text(label.servingCalories), findsOneWidget);
    expect(find.text(label.recipeCalories), findsOneWidget);
    expect(label.servingCalories, labelCalories(25));
    expect(label.recipeCalories, labelCalories(100));
    expect(find.text('Total Carbohydrate'), findsOneWidget);
    expect(find.text(vitamin), findsOneWidget);

    final frame = tester.widget<Container>(find.byKey(const ValueKey('nutrition-facts')));
    final decoration = frame.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFFFFFF));
    expect(decoration.border, Border.all(width: 2));
    expect(tester.getSize(find.byKey(const ValueKey('nutrition-facts'))).width, 326);
    expect(tester.takeException(), isNull);
  });
}

typedef _LabelRow = ({
  String name,
  List<String> serving,
  List<String> recipe,
  double nameInset,
  double height,
  double nameTop,
});

({Recipe recipe, String vitamin}) _labeledSample() {
  for (final MapEntry(:key, :value) in dailyValues.entries) {
    final measurements = {'Total Fat': '10 g', 'Saturated Fat': '1 g', 'Protein': '1 g'};
    if (measurements.containsKey(key)) continue;
    final recipe = _recipeMeasuring({
      ...measurements,
      key: '${value.amount} ${value.unit.name.short}',
    });
    if (NutritionLabel(recipe).vitamins.isNotEmpty) return (recipe: recipe, vitamin: key);
  }
  fail('Daily values need a vitamin');
}

Recipe _recipeMeasuring(Map<String, String> measurements) {
  final ingredient = Ingredient(
    name: 'sample',
    servingSize: const Measure(1, Unit.g),
    servings: 1,
    totalPrice: const Price(1),
    servingNutrition: const NutritionFacts(calories: 100, grams: {}),
    measurementText: measurements,
  );
  return Recipe(
    name: 'sample',
    meals: const ['side dish'],
    servings: 4,
    servingsSpecified: true,
    calculatesNutrition: true,
    lines: [RecipeLine('1 g sample', food: ingredient.used(const Measure(1, Unit.g)))],
    directions: const ['Eat.'],
  );
}

void _expectMeasured(List<_LabelRow> lines, String name, String measurement, double servings) {
  final total = Measure.parse(measurement);
  final daily = dailyValues[name]!;
  final serving = total.perServing(servings);
  final line = lines.singleWhere((line) => line.name == name);
  expect(line.serving, [serving.quantityText, serving.percentOf(daily)], reason: name);
  expect(line.recipe, [total.quantityText, total.percentOf(daily)], reason: name);
}

Future<List<_LabelRow>> _labelRows(WidgetTester tester, List<TableRow> rows) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: SingleChildScrollView(child: Table(children: rows)),
    ),
  );
  final cells = find.descendant(of: find.byType(Table), matching: find.byType(Padding));
  final result = <_LabelRow>[];
  final cellCount = cells.evaluate().length;
  for (var index = 0; index < cellCount; index += 3) {
    final name = cells.at(index);
    final nameText = find.descendant(of: name, matching: find.byType(Text));
    result.add((
      name: _strings(tester, nameText).single,
      serving: _strings(
        tester,
        find.descendant(of: cells.at(index + 1), matching: find.byType(Text)),
      ),
      recipe: _strings(
        tester,
        find.descendant(of: cells.at(index + 2), matching: find.byType(Text)),
      ),
      nameInset: _leftInset(tester, name),
      height: tester.getSize(name).height,
      nameTop: tester.getTopLeft(nameText).dy - tester.getTopLeft(name).dy,
    ));
  }
  return result;
}

List<String> _strings(WidgetTester tester, Finder finder) => [
  for (final text in tester.widgetList<Text>(finder)) ?text.data,
];

double _leftInset(WidgetTester tester, Finder finder) {
  final padding = tester.widget<Padding>(finder).padding;
  return (padding as EdgeInsets).left;
}
