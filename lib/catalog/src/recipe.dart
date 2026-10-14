part of '../catalog.dart';

class RecipeLine {
  const new(this.text, {this.food, this.group, this.optional = false, this.ignored = false});

  final String text;
  final IngredientAmount? food;
  final String? group;
  final bool optional;
  final bool ignored;
}

class Recipe implements Food {
  new({
    required this.name,
    required this.tags,
    required this.servings,
    required this.servingsSpecified,
    required this.calculatesNutrition,
    required this.lines,
    required this.directions,
  }) : assert(servings > 0, 'A recipe needs at least one serving');

  @override
  final String name;
  final List<String> tags;
  @override
  final double servings;
  final bool servingsSpecified;
  final bool calculatesNutrition;
  final List<RecipeLine> lines;
  final List<String> directions;

  late final bool isPriced = _hasPrice();

  @override
  late final Price totalPrice = isPriced ? _sumPrices() : const Price(0);

  @override
  late final NutritionFacts totalNutrition = isPriced ? _sumNutrition() : .none;

  late final String _searchText = _searchableText();

  @override
  Price get servingPrice => totalPrice / servings;

  @override
  NutritionFacts get servingNutrition => totalNutrition / servings;

  /// Null when the recipe is one batch.
  String? get specifiedServings => servingsSpecified ? servings.plainNumber : null;

  String get ingredientLinesText {
    final buffer = StringBuffer();
    String? group;
    for (final line in lines) {
      if (line.group != group) {
        if (buffer.isNotEmpty) buffer.writeln();
        group = line.group;
        if (group != null) buffer.writeln('$group:');
      }
      buffer.writeln(line.text);
    }
    return buffer.toString().trimRight();
  }

  bool matches(Iterable<String> requiredTags, String query) {
    for (final tag in requiredTags) {
      if (!tags.contains(tag)) return false;
    }
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return _searchText.contains(normalized);
  }

  bool _hasPrice() {
    if (!calculatesNutrition) return false;
    var anyRequired = false;
    for (final line in lines) {
      if (line.optional || line.ignored) continue;
      anyRequired = true;
      if (line.food == null) return false;
    }
    return anyRequired;
  }

  Price _sumPrices() {
    var dollars = 0.0;
    for (final line in lines) {
      if (line case RecipeLine(optional: false, ignored: false, :final food?)) {
        dollars += food.totalPrice.dollars;
      }
    }
    return Price(dollars);
  }

  NutritionFacts _sumNutrition() {
    NutritionFacts sum = .none;
    for (final line in lines) {
      if (line case RecipeLine(optional: false, ignored: false, :final food?)) {
        sum += food.totalNutrition;
      }
    }
    return sum;
  }

  String _searchableText() {
    final haystack = StringBuffer(name);
    for (final tag in tags) {
      haystack
        ..write('\n')
        ..write(tag);
    }
    for (final line in lines) {
      haystack
        ..write('\n')
        ..write(line.text);
    }
    for (final direction in directions) {
      haystack
        ..write('\n')
        ..write(direction);
    }
    return haystack.toString().toLowerCase();
  }
}
