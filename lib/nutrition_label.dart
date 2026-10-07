import 'package:material_ui/material_ui.dart';

import 'catalog.dart';
import 'measure.dart';

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

const _innerWidth = 320.0;
const _nameWidth = 146.0;
const _servingWidth = 86.0;
const _recipeWidth = 88.0;
const _dividerLeft = _nameWidth + _servingWidth;

const _headerStyle = TextStyle(fontSize: 10, height: 1.1);
const _bodyBold = TextStyle(fontWeight: .w700);
const _calorieStyle = TextStyle(fontSize: 18, height: 21 / 18, fontWeight: .w700);

class NutritionLabel extends StatelessWidget {
  factory(Recipe recipe, {Key? key}) {
    var calories = 0.0;
    final totals = {
      for (final nutrient in _macros) nutrient.key: Measure(0, dailyValues[nutrient.key]!.unit),
    };
    final vitaminTotals = <String, Measure>{};
    for (final line in recipe.lines) {
      if (line case RecipeLine(optional: false, ignored: false, :final food?)) {
        final ratio = food.servings;
        calories += food.servingNutrition.calories * ratio;
        for (final MapEntry(:key, :value) in food.ingredient.measurementText.entries) {
          final scaled = Measure.parse(value) * ratio;
          if (totals[key] case final previous?) {
            totals[key] = previous + scaled;
          } else {
            vitaminTotals[key] = switch (vitaminTotals[key]) {
              final previous? => previous + scaled,
              null => scaled,
            };
          }
        }
      }
    }
    return ._(
      key: key,
      yieldText: 'recipe yields ${_count(recipe.servings)} servings',
      servingCalories: labelCalories(calories / recipe.servings),
      recipeCalories: labelCalories(calories),
      macros: [
        for (final nutrient in _macros)
          _nutrientRow(
            name: nutrient.label,
            indented: nutrient.indented,
            thickRule: nutrient.thickRule,
            serving: totals[nutrient.key]!.perServing(recipe.servings),
            recipe: totals[nutrient.key]!,
            daily: dailyValues[nutrient.key]!,
          ),
      ],
      vitamins: [
        for (final MapEntry(:key, :value) in vitaminTotals.entries)
          if (dailyValues[key] case final dailyAmount?)
            _nutrientRow(
              name: key,
              indented: false,
              thickRule: false,
              percentOnly: true,
              serving: value.perServing(recipe.servings),
              recipe: value,
              daily: dailyAmount,
            ),
      ],
    );
  }

  const new _({
    super.key,
    required this.yieldText,
    required this.servingCalories,
    required this.recipeCalories,
    required this.macros,
    required this.vitamins,
  });

  final String yieldText;
  final String servingCalories;
  final String recipeCalories;
  final List<TableRow> macros;
  final List<TableRow> vitamins;

  @override
  Widget build(BuildContext context) {
    const widths = <int, TableColumnWidth>{
      0: FixedColumnWidth(_nameWidth),
      1: FixedColumnWidth(_servingWidth),
      2: FixedColumnWidth(_recipeWidth),
    };
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: .noScaling, boldText: false),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'Arial',
          fontFamilyFallback: ['Helvetica', 'Segoe UI'],
          color: _black,
          fontSize: 12,
          height: 14 / 12,
          fontWeight: .w400,
          letterSpacing: 0,
          wordSpacing: 0,
          decoration: .none,
          leadingDistribution: .even,
        ),
        maxLines: 1,
        softWrap: false,
        child: Center(
          heightFactor: 1,
          child: Container(
            key: const ValueKey('nutrition-facts'),
            decoration: BoxDecoration(color: _white, border: Border.all(width: 2)),
            padding: const .all(1),
            child: SizedBox(
              width: _innerWidth,
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  Padding(
                    padding: const .symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .stretch,
                      children: [
                        const SizedBox(
                          height: 37,
                          child: Align(
                            alignment: .bottomCenter,
                            child: Text(
                              'Nutrition Facts',
                              textAlign: .center,
                              style: TextStyle(
                                fontSize: 32,
                                height: 1,
                                fontWeight: .w800,
                                // Opt out of the label's even leading.
                                leadingDistribution: .proportional,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2, child: ColoredBox(color: _black)),
                        const SizedBox(height: 4),
                        Text(yieldText, textAlign: .center),
                        const SizedBox(height: 4),
                        const SizedBox(height: 16, child: ColoredBox(color: _black)),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                  Table(
                    columnWidths: widths,
                    children: [
                      const TableRow(
                        children: [
                          SizedBox(height: 16),
                          _HeadingCell('one serving'),
                          _HeadingCell('whole recipe', paddingLeft: 5),
                        ],
                      ),
                      TableRow(
                        decoration: _calorieRules,
                        children: _factCells(
                          lineHeight: 21,
                          rowHeight: 47,
                          name: Align(
                            alignment: .centerLeft,
                            child: Text('Calories', style: _calorieStyle),
                          ),
                          serving: Center(child: Text(servingCalories, style: _calorieStyle)),
                          recipe: Center(child: Text(recipeCalories, style: _calorieStyle)),
                        ),
                      ),
                      ...macros,
                    ],
                  ),
                  if (vitamins.isNotEmpty) Table(columnWidths: widths, children: vitamins),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MacroNutrient {
  const new(this.key, {String? label, this.indented = false, this.thickRule = false})
    : label = label ?? key;

  final String key;
  final String label;
  final bool indented;
  final bool thickRule;
}

const _macros = [
  _MacroNutrient('Total Fat'),
  _MacroNutrient('Saturated Fat', indented: true),
  _MacroNutrient('Cholesterol'),
  _MacroNutrient('Sodium'),
  _MacroNutrient('Total Carbs', label: 'Total Carbohydrate'),
  _MacroNutrient('Fiber', label: 'Dietary Fiber', indented: true),
  _MacroNutrient('Sugar', label: 'Sugars', indented: true),
  _MacroNutrient('Sugar Alcohol', indented: true),
  _MacroNutrient('Protein', thickRule: true),
];

/// Calories print as 0 below 5, to the nearest 5 through 50, and to the nearest 10 above that.
String labelCalories(double amount) {
  if (amount < 5) return '0';
  final increment = amount <= 50 ? 5 : 10;
  return '${(amount / increment).round() * increment}';
}

String _count(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}

typedef _Rule = ({double thickness, double bottom});

const _thinRules = _RowRules([(thickness: 2, bottom: 2)]);
const _thickRules = _RowRules([(thickness: 16, bottom: 4)]);
const _calorieRules = _RowRules([(thickness: 8, bottom: 12), (thickness: 2, bottom: 2)]);

TableRow _nutrientRow({
  required String name,
  required bool indented,
  required bool thickRule,
  required Measure serving,
  required Measure recipe,
  required Measure daily,
  bool percentOnly = false,
}) {
  Widget cell(Measure measure) {
    final percent = Align(
      alignment: .centerRight,
      child: Text(measure.percentOf(daily), style: _bodyBold),
    );
    if (percentOnly) return percent;

    final quantity = Positioned(left: 2, child: Text(measure.quantityText()));
    return Stack(alignment: .centerLeft, children: [quantity, percent]);
  }

  return TableRow(
    decoration: thickRule ? _thickRules : _thinRules,
    children: _factCells(
      lineHeight: 14,
      rowHeight: thickRule ? 40 : 24,
      nameIndent: indented ? 12 : 0,
      name: Align(
        alignment: .centerLeft,
        child: Text(name, style: indented || percentOnly ? null : _bodyBold),
      ),
      serving: cell(serving),
      recipe: cell(recipe),
    ),
  );
}

List<Widget> _factCells({
  required double lineHeight,
  required double rowHeight,
  required Widget name,
  required Widget serving,
  required Widget recipe,
  double nameIndent = 0,
}) {
  return [
    _FactCell(
      paddingLeft: 3 + nameIndent,
      lineHeight: lineHeight,
      rowHeight: rowHeight,
      child: name,
    ),
    _FactCell(paddingLeft: 3, lineHeight: lineHeight, rowHeight: rowHeight, child: serving),
    _FactCell(paddingLeft: 5, lineHeight: lineHeight, rowHeight: rowHeight, child: recipe),
  ];
}

class _HeadingCell extends StatelessWidget {
  const new(this.label, {this.paddingLeft = 3});

  final String label;
  final double paddingLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Padding(
        padding: .fromLTRB(paddingLeft, 4, 3, 1),
        child: Text(label, textAlign: .center, style: _headerStyle),
      ),
    );
  }
}

class _FactCell extends StatelessWidget {
  const new({
    required this.paddingLeft,
    required this.lineHeight,
    required this.rowHeight,
    required this.child,
  });

  final double paddingLeft;
  final double lineHeight;
  final double rowHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rowHeight,
      child: Padding(
        padding: .fromLTRB(paddingLeft, 2, 3, 0),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [SizedBox(height: lineHeight, child: child)],
        ),
      ),
    );
  }
}

/// Horizontal rules break around the divider, with 3px of white on either side.
class _RowRules extends Decoration {
  const new(this.rules);

  final List<_Rule> rules;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _RowRulesPainter(rules, onChanged);
}

class _RowRulesPainter extends BoxPainter {
  new(this.rules, VoidCallback? onChanged) : super(onChanged);

  final List<_Rule> rules;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final paint = Paint()..color = _black;
    canvas.drawRect(Rect.fromLTWH(offset.dx + _dividerLeft, offset.dy, 2, size.height), paint);
    const edge = 3.0;
    const leftWidth = _dividerLeft - edge * 2;
    const rightStart = _dividerLeft + 2 + edge;
    for (final (:thickness, :bottom) in rules) {
      final top = offset.dy + size.height - bottom - thickness;
      canvas.drawRect(Rect.fromLTWH(offset.dx + edge, top, leftWidth, thickness), paint);
      canvas.drawRect(
        Rect.fromLTWH(offset.dx + rightStart, top, _innerWidth - rightStart - edge, thickness),
        paint,
      );
    }
  }
}
