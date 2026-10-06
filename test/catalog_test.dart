import 'package:flutter_test/flutter_test.dart';
import 'package:offline_recipes/catalog.dart';
import 'package:offline_recipes/food.dart';
import 'package:offline_recipes/quantity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadCatalog();
  });

  test('one labeled serving costs and feeds one serving of the container', () {
    final flour = ingredients['whole wheat flour'];
    final oneServing = flour.used(flour.servingSize)!;

    expect(oneServing.totalPrice.dollars, flour.servingPrice.dollars);
    expect(oneServing.totalNutrition.calories, flour.servingNutrition.calories);
  });

  test('sixteen tablespoons of flour match one cup', () {
    final flour = ingredients['whole wheat flour'];
    expect(flour.servingSize.unit, Unit.cup);

    final cup = flour.used(Quantity(1.0, Unit.cup))!;
    final spoons = flour.used(Quantity(16.0, Unit.tbsp))!;

    expect(spoons.totalPrice.dollars, cup.totalPrice.dollars);
    expect(spoons.totalNutrition.calories, cup.totalNutrition.calories);
    expect(flour.used(Quantity(100.0, Unit.g))!.servings, 100 / Unit.cup.inGrams);
  });

  test('a mixed tablespoon amount scales from the pantry serving', () {
    final powder = ingredients['baking powder'];
    final cornbread = recipes['cornbread'];
    final line = cornbread.lines.firstWhere(
      (item) => item.text == '1 1/2 tablespoon baking powder',
    );
    final expected = (1.5 * Unit.tbsp.inMilliliters) / powder.servingSize.milliliters;

    expect(line.food!.servings, expected);
    expect(line.food!.totalPrice.dollars, powder.servingPrice.dollars * expected);
  });

  test('recipe names that differ from the pantry still measure the same food', () {
    final yeast = ingredients['fortified premium yeast flakes'];
    final yeastLine = recipes['popcorn'].lines.firstWhere(
      (item) => item.text == '1/2 teaspoon nutritional yeast',
    );
    final yeastServings = (0.5 * Unit.tsp.inMilliliters) / yeast.servingSize.milliliters;
    expect(yeastLine.food!.name, yeast.name);
    expect(yeastLine.food!.servings, yeastServings);

    final oil = ingredients['canola oil'];
    final oilLine = recipes['cornbread'].lines.firstWhere((item) => item.text == '1/2 cup oil');
    final oilServings = (0.5 * Unit.cup.inMilliliters) / oil.servingSize.milliliters;
    expect(oilLine.food!.name, oil.name);
    expect(oilLine.food!.servings, oilServings);

    final erythritol = ingredients['erythritol'];
    final icing = recipes['red velvet cake'].lines.firstWhere(
      (item) => item.text == '5 cups erythritol powder',
    );
    expect(icing.group, 'icing');
    expect(icing.food!.name, erythritol.name);
  });

  test('ounces of cream cheese scale from its tablespoon serving', () {
    final creamCheese = ingredients['plant-based cream cheese'];
    final line = recipes['red velvet cake'].lines.firstWhere(
      (item) => item.text == '16 oz plant-based cream cheese',
    );
    final ounces = Quantity(16.0, Unit.oz);

    expect(line.food!.servings, ounces.grams / creamCheese.servingSize.grams);
    expect(creamCheese.used(creamCheese.servingSize)!.servings, 1);
  });

  test('soy milk in ice cream is two cups of the pantry serving', () {
    final soy = ingredients['soy milk'];
    final line = recipes['ice cream'].lines.firstWhere((item) => item.text == '2 cups soy milk');
    final expected = (2 * Unit.cup.inMilliliters) / soy.servingSize.milliliters;

    expect(line.food!.servings, expected);
    expect(line.food!.totalPrice.dollars, soy.servingPrice.dollars * expected);
    expect(line.food!.totalNutrition.calories, soy.servingNutrition.calories * expected);
  });

  test('a priced recipe is the sum of its required foods', () {
    final priced = [
      for (final recipe in recipes)
        if (recipe.isPriced) recipe.name,
    ];
    expect(priced, containsAll(['ice cream', 'oatmeal', 'no-bake cookies']));

    for (final recipe in recipes.where((recipe) => recipe.isPriced)) {
      var dollars = 0.0;
      var calories = 0.0;
      for (final line in recipe.lines) {
        if (line.optional || line.ignored) continue;
        expect(line.food, isNotNull, reason: '${recipe.name}: ${line.text}');
        dollars += line.food!.totalPrice.dollars;
        calories += line.food!.totalNutrition.calories;
      }
      expect(recipe.totalPrice.dollars, dollars, reason: recipe.name);
      expect(recipe.totalNutrition.calories, calories, reason: recipe.name);
      expect(
        recipe.servingPrice.dollars,
        closeTo(dollars / recipe.servings, 1e-9),
        reason: recipe.name,
      );
      expect(
        recipe.servingNutrition.calories,
        closeTo(calories / recipe.servings, 1e-9),
        reason: recipe.name,
      );
    }
  });

  test('ignored ingredients are omitted from price and nutrition', () {
    final water = recipes['cornbread'].lines.firstWhere((line) => line.text == '1 1/2 cup water');
    final coloring = recipes['red velvet cake'].lines.firstWhere(
      (line) => line.text == '1/8 cup red food coloring',
    );
    final toppings = recipes['pizza'].lines.firstWhere(
      (line) => line.text == 'plant-based sausage, bell peppers, jalapeños, diced red onion, etc.',
    );
    expect(water.ignored, isTrue);
    expect(coloring.ignored, isTrue);
    expect(toppings.ignored, isTrue);

    final ingredient = Ingredient(
      name: 'test flour',
      servingSize: Quantity(1.0, Unit.cup),
      servings: 10.0,
      totalPrice: const Price(10.0),
      servingNutrition: const NutritionFacts(calories: 100.0, grams: {'Total Fat': 1.0}),
    );
    final used = ingredient.used(Quantity(1.0, Unit.cup))!;
    final recipe = Recipe(
      name: 'test',
      meals: const ['side dish'],
      servings: 1.0,
      servingsSpecified: true,
      calculatesNutrition: true,
      lines: [
        RecipeLine('1 cup test flour', food: used),
        RecipeLine('1 cup water', food: used, ignored: true),
      ],
      directions: const ['Mix.'],
    );

    expect(recipe.isPriced, isTrue);
    expect(recipe.totalPrice.dollars, ingredient.servingPrice.dollars);
    expect(recipe.totalNutrition.calories, 100);
    expect(recipe.totalNutrition.grams['Total Fat'], 1);
  });

  test('optional lines and disabled recipes do not invent a total', () {
    final ingredient = Ingredient(
      name: 'test flour',
      servingSize: Quantity(1.0, Unit.cup),
      servings: 10.0,
      totalPrice: const Price(10.0),
      servingNutrition: const NutritionFacts(calories: 100.0, grams: {'Total Fat': 1.0}),
    );
    final used = ingredient.used(Quantity(1.0, Unit.cup))!;
    final recipe = Recipe(
      name: 'test',
      meals: const ['side dish'],
      servings: 2.0,
      servingsSpecified: true,
      calculatesNutrition: true,
      lines: [
        RecipeLine('1 cup test flour', food: used),
        RecipeLine('1 cup extra (optional)', food: used, optional: true),
      ],
      directions: const ['Mix.'],
    );

    expect(recipe.isPriced, isTrue);
    expect(recipe.totalPrice.dollars, ingredient.servingPrice.dollars);
    expect(recipe.servingPrice.dollars, ingredient.servingPrice.dollars / 2);
    expect(recipe.totalNutrition.calories, 100);
    expect(recipe.servingNutrition.calories, 50);
    expect(recipe.totalNutrition.grams['Total Fat'], 1);

    final hidden = Recipe(
      name: 'hidden',
      meals: const ['side dish'],
      servings: 1.0,
      servingsSpecified: true,
      calculatesNutrition: false,
      lines: [RecipeLine('1 cup test flour', food: used)],
      directions: const ['Mix.'],
    );
    expect(hidden.isPriced, isFalse);
    expect(hidden.totalPrice.dollars, 0);
    expect(hidden.totalNutrition.calories, 0);

    final guacamole = recipes['guacamole'];
    expect(guacamole.calculatesNutrition, isFalse);
    expect(guacamole.isPriced, isFalse);

    final sandwich = recipes['pb & j'];
    expect(sandwich.servingsSpecified, isFalse);
    expect(sandwich.servings, 1);
    expect(sandwich.isPriced, isFalse);
  });

  test('search matches ingredients and directions within the selected meal', () {
    final rolls = recipes['cinnamon rolls'];

    expect(rolls.matches(null, 'dental floss'), isTrue);
    expect(rolls.matches(null, '  Erythritol '), isTrue);
    expect(rolls.matches(null, ''), isTrue);
    expect(rolls.matches('drink', 'dental floss'), isFalse);
    expect(rolls.matches(null, 'avocado'), isFalse);
  });

  test('every recipe keeps its meals, ingredients, and directions', () {
    expect(recipes, isNotEmpty);
    for (final recipe in recipes) {
      expect(recipe.meals, isNotEmpty, reason: recipe.name);
      expect(recipe.lines, isNotEmpty, reason: recipe.name);
      expect(recipe.directions, isNotEmpty, reason: recipe.name);
    }
  });

  test('daily values keep the units they were written in', () {
    expect(dailyValues.names.first, 'Calories');
    expect(dailyValues.calories, greaterThan(0));
    expect(dailyValues.amounts['Total Fat']!.unitLabel, 'g');
    expect(dailyValues.amounts['Sodium']!.unitLabel, 'mg');
    expect(dailyValues.amounts['Vitamin A']!.unitLabel, '\u00B5g');
    expect(dailyValues.amounts.containsKey('Calories'), isFalse);
  });
}
