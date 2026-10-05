import 'package:material_ui/material_ui.dart';
import 'package:signal_widgets/signal_widgets.dart';

import 'catalog.dart';
import 'food.dart';

final meal = signal<String?>(null);
final query = signal('');
final selected = signal<Recipe?>(null);

class CatalogPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        return Scaffold(
          appBar: AppBar(title: const Text('Recipes')),
          body: wide
              ? Row(
                  children: [
                    SizedBox(
                      width: 380,
                      child: RecipeBrowser(onOpen: (recipe) => selected.value = recipe),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(child: SelectedRecipe()),
                  ],
                )
              : RecipeBrowser(
                  onOpen: (recipe) {
                    selected.value = recipe;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: Text(titleCase(recipe.name))),
                          body: RecipeDetail(recipe: recipe, showTitle: false),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class RecipeBrowser extends StatelessWidget {
  const new({required this.onOpen, super.key});

  final ValueChanged<Recipe> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: RecipeSearchField()),
        const MealFilters(),
        Expanded(child: RecipeList(onOpen: onOpen)),
      ],
    );
  }
}

class RecipeSearchField extends StatefulWidget {
  const new({super.key});

  @override
  State<RecipeSearchField> createState() => _RecipeSearchFieldState();
}

class _RecipeSearchFieldState extends State<RecipeSearchField> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('recipe-search'),
      controller: _controller,
      textInputAction: .search,
      decoration: InputDecoration(
        hintText: 'Search recipes',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
        isDense: true,
      ),
      onChanged: (value) => query.value = value,
    );
  }
}

class MealFilters extends SignalWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final current = meal.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in [null, ...meals])
            FilterChip(
              key: ValueKey(option == null ? 'meal-all' : 'meal-$option'),
              label: Text(option == null ? 'All' : titleCase(option)),
              selected: current == option,
              onSelected: (_) => meal.value = option,
            ),
        ],
      ),
    );
  }
}

class RecipeList extends SignalWidget {
  const new({required this.onOpen, super.key});

  final ValueChanged<Recipe> onOpen;

  @override
  Widget build(BuildContext context) {
    final mealName = meal.value;
    final normalizedQuery = query.value.trim().toLowerCase();
    final selectedName = selected.value?.name;
    final matching = [
      for (final recipe in recipes)
        if (_matches(recipe, mealName, normalizedQuery)) recipe,
    ];
    if (matching.isEmpty) {
      return const Center(child: Text('No recipes match.'));
    }
    final theme = Theme.of(context);
    return ListView.separated(
      key: const ValueKey('recipe-list'),
      itemCount: matching.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final recipe = matching[index];
        return ListTile(
          key: ValueKey('recipe-${recipe.name}'),
          selected: recipe.name == selectedName,
          title: Text(titleCase(recipe.name)),
          subtitle: Text(recipeSubtitle(recipe)),
          trailing: recipe.isPriced
              ? Column(
                  mainAxisAlignment: .center,
                  crossAxisAlignment: .end,
                  mainAxisSize: .min,
                  children: [
                    Text(recipe.servingPrice.toString(), style: theme.textTheme.titleMedium),
                    if (recipe.servingsSpecified) Text('each', style: theme.textTheme.labelSmall),
                  ],
                )
              : null,
          onTap: () => onOpen(recipe),
        );
      },
    );
  }
}

class SelectedRecipe extends SignalWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final recipe = selected.value;
    if (recipe == null) {
      return const Center(child: Text('Select a recipe to read it.'));
    }
    return RecipeDetail(recipe: recipe, showTitle: true);
  }
}

class RecipeDetail extends StatelessWidget {
  const new({required this.recipe, required this.showTitle, super.key});

  final Recipe recipe;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    String? previousGroup;
    final children = <Widget>[
      if (showTitle) ...[
        Text(titleCase(recipe.name), style: textTheme.headlineMedium),
        const SizedBox(height: 8),
      ],
      Text(recipeSubtitle(recipe), style: textTheme.bodyMedium),
      if (recipe.isPriced) ...[
        const SizedBox(height: 16),
        _PriceSummary(recipe: recipe),
        const SizedBox(height: 8),
        Text(
          'Percent of a ${formatCalories(dailyValues.calories)} diet',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text(recipe.servingsSpecified ? 'Each serving' : 'Recipe', style: textTheme.titleSmall),
        const SizedBox(height: 4),
        _NutrientList(recipe: recipe),
      ],
      const SizedBox(height: 24),
      Text('Ingredients', style: textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final RecipeLine(:group, :text) in recipe.lines) ...[
        if (group != previousGroup)
          if (previousGroup = group case final group?)
            Padding(
              padding: const .only(top: 8, bottom: 4),
              child: Text(titleCase(group), style: textTheme.titleSmall),
            ),
        Padding(
          padding: const .only(bottom: 6),
          child: Row(
            crossAxisAlignment: .start,
            children: [
              const Padding(padding: .only(top: 8, right: 10), child: Icon(Icons.circle, size: 6)),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
      Text('Directions', style: textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final (i, item) in recipe.directions.indexed)
        Padding(
          padding: const .only(bottom: 12),
          child: Row(
            crossAxisAlignment: .start,
            children: [
              SizedBox(width: 28, child: Text('${i + 1}.')),
              Expanded(child: Text.rich(_directionSpan(item))),
            ],
          ),
        ),
    ];

    return ListView(
      key: const ValueKey('recipe-detail'),
      padding: const .fromLTRB(20, 16, 20, 32),
      children: children,
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const new({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    if (!recipe.servingsSpecified) {
      return _Stat(
        label: 'Recipe',
        price: recipe.totalPrice,
        calories: recipe.totalNutrition.calories,
      );
    }
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Per serving',
            price: recipe.servingPrice,
            calories: recipe.servingNutrition.calories,
          ),
        ),
        Expanded(
          child: _Stat(
            label: 'Whole recipe',
            price: recipe.totalPrice,
            calories: recipe.totalNutrition.calories,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.label, required this.price, required this.calories});

  final String label;
  final Price price;
  final double calories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(price.toString(), style: theme.textTheme.headlineSmall),
        Text(formatCalories(calories)),
      ],
    );
  }
}

class _NutrientList extends StatelessWidget {
  const new({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final facts = recipe.servingsSpecified ? recipe.servingNutrition : recipe.totalNutrition;
    final names = <String>[
      for (final name in dailyValues.names)
        if (name != 'Calories' && (facts.grams[name] ?? 0) > 0) name,
    ];
    for (final name in facts.grams.keys) {
      final grams = facts.grams[name] ?? 0;
      if (grams > 0 && !names.contains(name)) names.add(name);
    }
    return Column(
      children: [
        for (final name in names)
          if (_nutrientLabel(facts.grams[name]!, _unitFor(name, facts.grams[name]!))
              case final label?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(name)),
                  Text(label),
                  SizedBox(
                    width: 52,
                    child: Text(
                      _percent(facts.grams[name]!, dailyValues.amounts[name]?.grams),
                      textAlign: .end,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _unitFor(String name, double grams) {
    final labeled = dailyValues.amounts[name]?.unitLabel;
    if (labeled != null) return labeled;
    if (grams >= 1) return 'g';
    if (grams >= 0.001) return 'mg';
    return '\u00B5g';
  }

  String? _nutrientLabel(double grams, String unitLabel) {
    final value = switch (unitLabel) {
      'mg' => grams * 1000,
      '\u00B5g' => grams * 1000000,
      _ => grams,
    };
    final number = _formatDecimal(value);
    if (number == '0') return null;
    return '$number $unitLabel';
  }

  String _percent(double grams, double? dailyGrams) {
    if (dailyGrams == null || dailyGrams == 0) return '';
    return '${(grams / dailyGrams * 100).round()}%';
  }
}

bool _matches(Recipe recipe, String? meal, String query) {
  if (meal != null && !recipe.meals.contains(meal)) return false;
  if (query.isEmpty) return true;
  final haystack = StringBuffer(recipe.name);
  for (final mealName in recipe.meals) {
    haystack
      ..write('\n')
      ..write(mealName);
  }
  for (final line in recipe.lines) {
    haystack
      ..write('\n')
      ..write(line.text);
  }
  for (final direction in recipe.directions) {
    haystack
      ..write('\n')
      ..write(direction);
  }
  return haystack.toString().toLowerCase().contains(query);
}

String recipeSubtitle(Recipe recipe) {
  final parts = <String>[recipe.meals.map(titleCase).join(', ')];
  if (recipe.servingsSpecified) {
    final count = _formatCount(recipe.servings);
    final noun = recipe.servings == 1 ? 'serving' : 'servings';
    parts.add('$count $noun');
  }
  return parts.where((part) => part.isNotEmpty).join(' · ');
}

String titleCase(String text) {
  return text
      .split(' ')
      .map((word) {
        return word
            .split('-')
            .map((part) {
              if (part.isEmpty) return part;
              return part[0].toUpperCase() + part.substring(1);
            })
            .join('-');
      })
      .join(' ');
}

String formatCalories(double calories) {
  if (calories.abs() >= 10) return '${calories.round()} Cal';
  final text = calories.toStringAsFixed(1);
  final number = text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  return '$number Cal';
}

String _formatCount(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}

String _formatDecimal(double value) {
  final places = value.abs() >= 100 ? 0 : (value.abs() >= 10 ? 1 : 2);
  var text = value.toStringAsFixed(places);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  if (text == '-0') return '0';
  return text;
}

TextSpan _directionSpan(String source) {
  final text = source.replaceAll('<br>', '\n').trim();
  final pattern = RegExp(r'\*\*(.+?)\*\*|\[(.+?)\]\([^)]*\)');
  final children = <TextSpan>[];
  var index = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > index) {
      children.add(TextSpan(text: text.substring(index, match.start)));
    }
    final bold = match.group(1);
    if (bold != null) {
      children.add(
        TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    } else {
      children.add(TextSpan(text: match.group(2)));
    }
    index = match.end;
  }
  if (index < text.length) {
    children.add(TextSpan(text: text.substring(index)));
  }
  return TextSpan(children: children);
}
