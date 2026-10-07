import 'package:material_ui/material_ui.dart';
import 'package:signal_widgets/signal_widgets.dart';

import 'catalog.dart';
import 'food.dart';
import 'nutrition_label.dart';

final tag = signal<String?>(null);
final query = signal('');
final selected = signal<Recipe?>(null);

const navKey = GlobalObjectKey<NavigatorState>(#navigator);
NavigatorState get navigator => navKey.currentState!;

class CatalogPage extends StatelessWidget {
  const new({super.key});

  static void _navigateRecipe(Recipe recipe) {
    final route = MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(titleCase(recipe.name))),
        body: RecipeDetail(recipe: recipe, showTitle: false),
      ),
    );
    navigator.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleTextStyle: TextTheme.of(context).bodyLarge,
        excludeHeaderSemantics: true,
        notificationPredicate: (_) => false,
        title: const RecipeSearchField(),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth >= 840
              ? const Row(
                  children: [
                    SizedBox(width: 380, child: RecipeBrowser()),
                    VerticalDivider(width: 1),
                    Expanded(child: SelectedRecipe()),
                  ],
                )
              : const RecipeBrowser(onSelect: _navigateRecipe);
        },
      ),
    );
  }
}

class RecipeBrowser extends StatelessWidget {
  const new({this.onSelect, super.key});

  final ValueChanged<Recipe>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const TagFilters(),
        Expanded(
          child: SignalBuilder(
            builder: (context) {
              final tagName = tag.value;
              final text = query.value;
              final matching = [
                for (final recipe in recipes)
                  if (recipe.matches(tagName, text)) recipe,
              ];
              if (matching.isEmpty) {
                return const Center(child: Text('No recipes match.'));
              }
              return ListView.separated(
                key: const ValueKey('recipe-list'),
                itemCount: matching.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final recipe = matching[index];
                  return _RecipeTile(
                    key: ValueKey('recipe-${recipe.name}'),
                    recipe: recipe,
                    onSelect: onSelect,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecipeTile extends SignalStatefulWidget {
  const new({required this.recipe, required this.onSelect, super.key});

  final Recipe recipe;
  final ValueChanged<Recipe>? onSelect;

  @override
  State<_RecipeTile> createState() => _RecipeTileState();
}

class _RecipeTileState extends State<_RecipeTile> {
  late final ReadonlySignal<bool> _highlighted = computed(_isHighlighted);

  bool _isHighlighted() => selected.value == widget.recipe;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final textTheme = TextTheme.of(context);
    final highlighted = _highlighted.value;
    return ListTile(
      selected: highlighted,
      title: Text(titleCase(recipe.name)),
      subtitle: Text(recipeSubtitle(recipe)),
      trailing: recipe.isPriced
          ? Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .end,
              mainAxisSize: .min,
              children: [
                Text(recipe.servingPrice.toString(), style: textTheme.titleMedium),
                if (recipe.servingsSpecified) Text('each', style: textTheme.labelSmall),
              ],
            )
          : null,
      onTap: () {
        selected.value = recipe;
        widget.onSelect?.call(recipe);
      },
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

class TagFilters extends SignalWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final current = tag.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in tags)
            FilterChip(
              key: ValueKey('tag-$option'),
              label: Text(titleCase(option)),
              selected: current == option,
              onSelected: (selected) => tag.value = selected ? option : null,
            ),
        ],
      ),
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

class RecipeDetail extends SignalStatefulWidget {
  const new({required this.recipe, required this.showTitle, super.key});

  final Recipe recipe;
  final bool showTitle;

  @override
  State<RecipeDetail> createState() => _RecipeDetailState();
}

class _RecipeDetailState extends State<RecipeDetail> {
  final _checked = setSignal(<int>{});

  @override
  void didUpdateWidget(RecipeDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe != widget.recipe) _checked.clear();
  }

  void _toggleIngredient(int index, bool? selected) {
    if (selected ?? false) {
      _checked.add(index);
    } else {
      _checked.remove(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RecipeDetail(:recipe, :showTitle) = widget;
    final textTheme = TextTheme.of(context);
    final quiet = Theme.of(context)
        .copyWith(splashFactory: NoSplash.splashFactory, highlightColor: Colors.transparent);
    final faded = TextStyle(color: ColorScheme.of(context).onSurface.withValues(alpha: 0.5));
    String? previousGroup;
    final children = <Widget>[
      if (showTitle) ...[
        Text(titleCase(recipe.name), style: textTheme.headlineMedium),
        const SizedBox(height: 8),
      ],
      Text(recipeSubtitle(recipe), style: textTheme.bodyMedium),
      const SizedBox(height: 24),
      Text('Ingredients', style: textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final (index, RecipeLine(:group, :text)) in recipe.lines.indexed) ...[
        if (group != previousGroup)
          if (previousGroup = group case final group?)
            Padding(
              padding: const .only(top: 8, bottom: 4),
              child: Text(titleCase(group), style: textTheme.titleSmall),
            ),
        Theme(
          data: quiet,
          child: CheckboxListTile(
            key: ValueKey('ingredient-$index'),
            value: _checked.contains(index),
            onChanged: (selected) => _toggleIngredient(index, selected),
            overlayColor: .all(Colors.transparent),
            controlAffinity: .leading,
            contentPadding: .zero,
            visualDensity: .compact,
            dense: true,
            horizontalTitleGap: 4,
            minVerticalPadding: 0,
            titleAlignment: .top,
            title: Text(text, style: _checked.contains(index) ? faded : null),
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
      if (recipe.isPriced) ...[
        const SizedBox(height: 12),
        _PriceSummary(recipe: recipe),
        const SizedBox(height: 16),
        NutritionLabel(recipe),
      ],
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
      return _Stat(label: 'Recipe', price: recipe.totalPrice);
    }
    return Row(
      children: [
        Expanded(
          child: _Stat(label: 'Per serving', price: recipe.servingPrice),
        ),
        Expanded(
          child: _Stat(label: 'Whole recipe', price: recipe.totalPrice),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.label, required this.price});

  final String label;
  final Price price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(price.toString(), style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

String recipeSubtitle(Recipe recipe) {
  final parts = <String>[recipe.tags.map(titleCase).join(', ')];
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

String _formatCount(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
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
