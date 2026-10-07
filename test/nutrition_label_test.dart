import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:offline_recipes/catalog.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/nutrition_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadCatalog();
  });

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

  testWidgets('ice cream label sums the pantry into each row', (tester) async {
    final table = NutritionLabel(recipes['ice cream']);

    expect(table.yieldText, 'recipe yields 12 servings');
    expect(table.servingCalories, '160');
    expect(table.recipeCalories, '1960');
    final lines = await _labelRows(tester, table.macros);
    _expectLine(lines, 'Total Fat', '14g', '18%', '171g', '219%');
    _expectLine(lines, 'Saturated Fat', '7.9g', '40%', '95g', '476%');
    _expectLine(lines, 'Cholesterol', '0mg', '0%', '0mg', '0%');
    _expectLine(lines, 'Sodium', '153mg', '7%', '1835mg', '80%');
    _expectLine(lines, 'Total Carbohydrate', '25g', '9%', '306g', '111%');
    _expectLine(lines, 'Dietary Fiber', '1.8g', '6%', '22g', '77%');
    _expectLine(lines, 'Sugars', '0.2g', '0%', '2.0g', '4%');
    _expectLine(lines, 'Sugar Alcohol', '8.0g', '44%', '96g', '533%');
    _expectLine(lines, 'Protein', '2.2g', '4%', '26g', '52%');
    final fat = lines.singleWhere((line) => line.name == 'Total Fat');
    expect(
      lines.singleWhere((line) => line.name == 'Saturated Fat').nameInset,
      greaterThan(fat.nameInset),
    );
    expect(lines.singleWhere((line) => line.name == 'Protein').height, greaterThan(fat.height));
    _expectVitamins(await _labelRows(tester, table.vitamins), {
      'Vitamin D': ('6%', '76%'),
      'Calcium': ('8%', '101%'),
      'Potassium': ('2%', '29%'),
      'Iron': ('3%', '31%'),
      'Vitamin A': ('6%', '71%'),
      'Folic Acid': ('2%', '20%'),
      'Phosphorus': ('1%', '16%'),
      'Riboflavin': ('7%', '88%'),
      'Vitamin B12': ('15%', '183%'),
      'Magnesium': ('0%', '0%'),
      'Iodine': ('4%', '45%'),
    });
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

  testWidgets('the label paints the nutrition facts frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListView(children: [NutritionLabel(recipes['ice cream'])])),
      ),
    );

    expect(find.text('Nutrition Facts'), findsOneWidget);
    expect(find.text('recipe yields 12 servings'), findsOneWidget);
    expect(find.text('one serving'), findsOneWidget);
    expect(find.text('whole recipe'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('160'), findsOneWidget);
    expect(find.text('1960'), findsOneWidget);
    expect(find.text('Total Carbohydrate'), findsOneWidget);
    expect(find.text('Vitamin D'), findsOneWidget);

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
});

Future<List<_LabelRow>> _labelRows(WidgetTester tester, List<TableRow> rows) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: SingleChildScrollView(child: Table(children: rows)),
    ),
  );
  final cells = find.descendant(of: find.byType(Table), matching: find.byType(Column));
  final result = <_LabelRow>[];
  final cellCount = cells.evaluate().length;
  for (var index = 0; index < cellCount; index += 3) {
    final name = cells.at(index);
    result.add((
      name: _strings(tester, find.descendant(of: name, matching: find.byType(Text))).single,
      serving: _strings(
        tester,
        find.descendant(of: cells.at(index + 1), matching: find.byType(Text)),
      ),
      recipe: _strings(
        tester,
        find.descendant(of: cells.at(index + 2), matching: find.byType(Text)),
      ),
      nameInset: _leftInset(tester, find.ancestor(of: name, matching: find.byType(Padding))),
      height: _rowHeight(tester, find.ancestor(of: name, matching: find.byType(SizedBox))),
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

double _rowHeight(WidgetTester tester, Finder finder) {
  return tester.firstWidget<SizedBox>(finder).height!;
}

void _expectLine(
  List<_LabelRow> lines,
  String name,
  String servingAmount,
  String servingDailyValue,
  String recipeAmount,
  String recipeDailyValue,
) {
  final line = lines.singleWhere((line) => line.name == name);
  expect(line.serving, [servingAmount, servingDailyValue], reason: name);
  expect(line.recipe, [recipeAmount, recipeDailyValue], reason: name);
}

void _expectVitamins(List<_LabelRow> lines, Map<String, (String, String)> expected) {
  expect([for (final line in lines) line.name], expected.keys.toList());
  for (final MapEntry(:key, :value) in expected.entries) {
    final line = lines.singleWhere((line) => line.name == key);
    expect(line.serving, [value.$1], reason: key);
    expect(line.recipe, [value.$2], reason: key);
  }
}
