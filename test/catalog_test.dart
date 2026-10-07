import 'package:flutter_test/flutter_test.dart';
import 'package:offline_recipes/catalog.dart';
import 'package:offline_recipes/food.dart';
import 'package:offline_recipes/measure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadCatalog);

  test('one serving of the serving size costs and feeds one serving', () {
    final ingredient = _ingredient();
    final oneServing = ingredient.used(ingredient.servingSize)!;

    expect(oneServing.servings, 1);
    expect(oneServing.totalPrice.dollars, ingredient.servingPrice.dollars);
    expect(oneServing.totalNutrition.calories, ingredient.servingNutrition.calories);
  });

  test('sixteen tablespoons match one cup of the same food', () {
    final ingredient = _ingredient();
    final cup = ingredient.used(const Measure(1, Unit.cup))!;
    final spoons = ingredient.used(const Measure(16, Unit.tbsp))!;

    expect(spoons.servings, cup.servings);
    expect(spoons.totalPrice.dollars, cup.totalPrice.dollars);
    expect(spoons.totalNutrition.calories, cup.totalNutrition.calories);
    expect(ingredient.used(const Measure(100, Unit.g))!.servings, 100 / Unit.cup.inGrams);
  });

  test('a mixed number scales from the serving size', () {
    final ingredient = _ingredient(servingSize: const Measure(1, Unit.tbsp));
    final measure = parseMeasure('1 1/2 tablespoon');
    final expected = measure.milliliters / ingredient.servingSize.milliliters;
    final used = ingredient.used(measure)!;

    expect(used.servings, expected);
    expect(used.totalPrice.dollars, ingredient.servingPrice.dollars * expected);
  });

  test('ounces scale along grams when the serving is a volume', () {
    final ingredient = _ingredient(servingSize: const Measure(2, Unit.tbsp));
    const ounces = Measure(16, Unit.oz);
    final used = ingredient.used(ounces)!;

    expect(used.servings, ounces.grams / ingredient.servingSize.grams);
    expect(ingredient.used(ingredient.servingSize)!.servings, 1);
  });

  test('aliases resolve and ignored names drop out when a line is read', () {
    expect(ingredientAliases, isNotEmpty);
    for (final MapEntry(:key, :value) in ingredientAliases.entries) {
      final ingredient = _ingredient(name: value);
      final line = recipeLineFor('1 cup $key', {value: ingredient});

      expect(line.food, isNotNull, reason: key);
      expect(line.food!.name, value, reason: key);
      expect(line.food!.servings, 1, reason: key);
      expect(line.ignored, isFalse, reason: key);
    }

    expect(ignoredIngredientNames, isNotEmpty);
    for (final name in ignoredIngredientNames) {
      expect(recipeLineFor(name, const {}).ignored, isTrue, reason: name);
      expect(recipeLineFor('2 cups $name', const {}).ignored, isTrue, reason: name);
    }

    final ingredient = _ingredient();
    final pantry = {ingredient.name.toLowerCase(): ingredient};
    final plain = recipeLineFor('1 cup ${ingredient.name}', pantry, group: 'icing');
    expect(plain.group, 'icing');
    expect(plain.optional, isFalse);
    expect(plain.ignored, isFalse);
    expect(plain.food!.servings, 1);

    final optional = recipeLineFor('1 cup ${ingredient.name} (optional)', pantry);
    expect(optional.optional, isTrue);
    expect(optional.food!.servings, 1);

    expect(recipeLineFor('salt to taste', pantry).food, isNull);
  });

  test('a priced recipe is the sum of its required foods', () {
    for (final recipe in recipes) {
      if (!recipe.isPriced) {
        expect(recipe.totalPrice.dollars, 0, reason: recipe.name);
        expect(recipe.totalNutrition.calories, 0, reason: recipe.name);
        continue;
      }

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

  test('a measured line agrees with the pantry serving it names', () {
    for (final recipe in recipes) {
      for (final line in recipe.lines) {
        final reason = '${recipe.name}: ${line.text}';
        if (line.text.toLowerCase().contains('(optional)')) {
          expect(line.optional, isTrue, reason: reason);
        }
        final food = line.food;
        if (food == null) continue;
        final parsed = tryParseAmount(line.text);
        expect(parsed, isNotNull, reason: reason);
        final again = ingredients[food.name].used(parsed!.measure);
        expect(again, isNotNull, reason: reason);
        expect(food.servings, again!.servings, reason: reason);
        expect(food.totalPrice.dollars, again.totalPrice.dollars, reason: reason);
      }
    }
  });

  test('ignored and optional foods are left out of the total', () {
    final ingredient = _ingredient();
    final used = ingredient.used(ingredient.servingSize)!;
    final recipe = _recipe(
      lines: [
        RecipeLine('1 cup test flour', food: used),
        RecipeLine('1 cup water', food: used, ignored: true),
        RecipeLine('1 cup extra (optional)', food: used, optional: true),
      ],
    );

    expect(recipe.isPriced, isTrue);
    expect(recipe.totalPrice.dollars, ingredient.servingPrice.dollars);
    expect(recipe.totalNutrition.calories, ingredient.servingNutrition.calories);
    expect(recipe.totalNutrition.grams['Total Fat'], 1);

    final hidden = _recipe(
      calculatesNutrition: false,
      lines: [RecipeLine('1 cup test flour', food: used)],
    );
    expect(hidden.isPriced, isFalse);
    expect(hidden.totalPrice.dollars, 0);
    expect(hidden.totalNutrition.calories, 0);

    final unmeasured = _recipe(lines: const [RecipeLine('salt to taste')]);
    expect(unmeasured.isPriced, isFalse);
    expect(unmeasured.totalPrice.dollars, 0);
    expect(unmeasured.totalNutrition.calories, 0);
  });

  test('servings split a priced recipe', () {
    final ingredient = _ingredient();
    final used = ingredient.used(ingredient.servingSize)!;
    final recipe = _recipe(servings: 2, lines: [RecipeLine('1 cup test flour', food: used)]);

    expect(recipe.totalPrice.dollars, ingredient.servingPrice.dollars);
    expect(recipe.servingPrice.dollars, ingredient.servingPrice.dollars / 2);
    expect(recipe.totalNutrition.calories, ingredient.servingNutrition.calories);
    expect(recipe.servingNutrition.calories, ingredient.servingNutrition.calories / 2);
  });

  test('search matches the name, ingredients, and directions in the selected meal', () {
    final recipe = _recipe(
      name: 'cinnamon rolls',
      meals: const ['breakfast'],
      lines: const [RecipeLine('1 cup erythritol')],
      directions: const ['Cut with dental floss.'],
    );

    expect(recipe.matches(null, 'dental floss'), isTrue);
    expect(recipe.matches(null, '  Erythritol '), isTrue);
    expect(recipe.matches(null, 'cinnamon'), isTrue);
    expect(recipe.matches(null, ''), isTrue);
    expect(recipe.matches('breakfast', 'dental floss'), isTrue);
    expect(recipe.matches('drink', 'dental floss'), isFalse);
    expect(recipe.matches('drink', ''), isFalse);
    expect(recipe.matches(null, 'avocado'), isFalse);
  });
}

Ingredient _ingredient({
  String name = 'test flour',
  Measure servingSize = const Measure(1, Unit.cup),
  double servings = 10,
  Price totalPrice = const Price(10),
  NutritionFacts servingNutrition = const NutritionFacts(calories: 100, grams: {'Total Fat': 1}),
}) {
  return Ingredient(
    name: name,
    servingSize: servingSize,
    servings: servings,
    totalPrice: totalPrice,
    servingNutrition: servingNutrition,
  );
}

Recipe _recipe({
  required List<RecipeLine> lines,
  String name = 'test',
  List<String> meals = const ['side dish'],
  double servings = 1,
  bool calculatesNutrition = true,
  List<String> directions = const ['Mix.'],
}) {
  return Recipe(
    name: name,
    meals: meals,
    servings: servings,
    servingsSpecified: true,
    calculatesNutrition: calculatesNutrition,
    lines: lines,
    directions: directions,
  );
}
