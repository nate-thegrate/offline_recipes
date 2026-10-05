import 'package:flutter_test/flutter_test.dart';
import 'package:offline_recipes/food.dart';

void main() {
  test('one milligram weighs a thousandth of a gram', () {
    expect(Unit.mg.inGrams, 0.001);
    expect(Unit.mg.inMilliliters, Unit.mg.inGrams);
    expect(Unit.mg.measuresMass, isTrue);
  });

  test('sixteen ounces weigh one pound', () {
    expect(Unit.oz.inGrams * 16, Unit.lb.inGrams);
    expect(Unit.oz.inMilliliters, Unit.oz.inGrams);
    expect(Unit.oz.measuresMass, isTrue);
  });

  test('spoons and fluid ounces are the culinary fractions of a cup', () {
    expect(Unit.tbsp.inMilliliters, 15);
    expect(Unit.tsp.inMilliliters, 5);
    expect(Unit.flOz.inMilliliters, 30);
    expect(Unit.tbsp.inGrams, Unit.tbsp.inMilliliters);
    expect(Unit.tsp.inGrams, Unit.tsp.inMilliliters);
    expect(Unit.flOz.inGrams, Unit.flOz.inMilliliters);
    expect(Unit.cup.measuresMass, isFalse);
    expect(Unit.flOz.measuresMass, isFalse);
  });

  test('cup fractions, milliliters, and liters are one volume', () {
    expect(16 * Unit.tbsp.inMilliliters, Unit.cup.inMilliliters);
    expect(3 * Unit.tsp.inMilliliters, Unit.tbsp.inMilliliters);
    expect(8 * Unit.flOz.inMilliliters, Unit.cup.inMilliliters);
    expect(1000 * Unit.ml.inMilliliters, Unit.liter.inMilliliters);
    expect(200 * Unit.tsp.inMilliliters, Unit.liter.inMilliliters);
  });
}
