import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signal_widgets/signal_widgets.dart';

import 'package:offline_recipes/catalog/catalog.dart';
import 'package:offline_recipes/food.dart';
import 'package:offline_recipes/measure.dart';
import 'package:offline_recipes/settings/settings.dart';

part 'src/ingredient_editor.dart';
part 'src/recipe_editor.dart';
part 'src/nutrition_label.dart';

void _selectTag(String option) {
  if (HardwareKeyboard.instance.isShiftPressed) {
    _toggleTag(option);
    return;
  }
  final onlyThis = selectedTags.length == 1 && selectedTags.contains(option);
  selectedTags.clear();
  if (!onlyThis) selectedTags.add(option);
}

void _toggleTag(String option) {
  if (!selectedTags.remove(option)) selectedTags.add(option);
}

const navKey = GlobalObjectKey<NavigatorState>(#navigator);
NavigatorState get navigator => navKey.currentState!;

class CatalogPage extends StatelessWidget {
  const new({super.key});

  static void _navigateRecipe(Recipe recipe) {
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(actions: const [SettingsButton()]),
          body: RecipeDetail(recipe: recipe, showTitle: true, popWhenDeleted: true),
        ),
      ),
    );
  }

  static void _newRecipe() {
    navigator.push(MaterialPageRoute<void>(builder: (context) => const RecipeEditor()));
  }

  static void _openIngredients() {
    navigator.push(MaterialPageRoute<void>(builder: (context) => const IngredientListPage()));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showMenu = constraints.maxWidth < 600;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            titleTextStyle: TextTheme.of(context).bodyLarge,
            excludeHeaderSemantics: true,
            notificationPredicate: (_) => false,
            title: RecipeSearchField(showMenu: showMenu),
            actions: showMenu
                ? null
                : const [
                    IconButton(
                      key: ValueKey('new-recipe'),
                      tooltip: 'New recipe',
                      onPressed: _newRecipe,
                      icon: Icon(Icons.add),
                    ),
                    IconButton(
                      key: ValueKey('open-ingredients'),
                      tooltip: 'Ingredients',
                      onPressed: _openIngredients,
                      icon: Icon(Icons.kitchen_outlined),
                    ),
                    SettingsButton(),
                  ],
            titleSpacing: 8,
            actionsPadding: .only(right: 8),
          ),
          body: constraints.maxWidth >= 840
              ? const Row(
                  children: [
                    SizedBox(width: 380, child: RecipeBrowser()),
                    VerticalDivider(width: 1),
                    Expanded(child: SelectedRecipe()),
                  ],
                )
              : const RecipeBrowser(onSelect: _navigateRecipe),
        );
      },
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
              final matching = recipes.matching.value;
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
    final price = switch (listPrice.value) {
      .hidden => null,
      .serving => recipe.servingPrice,
      .recipe => recipe.totalPrice,
    };
    Widget? trailing;
    if (recipe.isPriced && price != null) {
      trailing = Text(price.toString(), style: TextTheme.of(context).titleMedium);
    }

    return ListTile(
      selected: _highlighted.value,
      title: Text(recipe.name.titleCase),
      subtitle: Text(recipe.subtitle),
      trailing: trailing,
      onTap: () {
        selected.value = recipe;
        widget.onSelect?.call(recipe);
      },
    );
  }
}

class SettingsButton extends StatelessWidget {
  const new({super.key});

  static void _open() {
    navigator.push(MaterialPageRoute<void>(builder: (context) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return const IconButton(
      key: ValueKey('open-settings'),
      tooltip: 'Settings',
      onPressed: _open,
      icon: Icon(Icons.settings_outlined),
    );
  }
}

class RecipeSearchField extends StatelessWidget {
  const new({this.showMenu = false, super.key});

  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('recipe-search'),
      controller: recipes.controller,
      textInputAction: .search,
      decoration: InputDecoration(
        hintText: 'Search recipes',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: showMenu ? const _CatalogMenu() : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
        isDense: true,
      ),
    );
  }
}

class _CatalogMenu extends StatelessWidget {
  const new();

  static List<PopupMenuEntry<void>> _items(BuildContext _) => const [
    PopupMenuItem(
      key: ValueKey('new-recipe'),
      onTap: CatalogPage._newRecipe,
      child: _CatalogMenuLabel(Icons.add, 'New recipe'),
    ),
    PopupMenuItem(
      key: ValueKey('open-ingredients'),
      onTap: CatalogPage._openIngredients,
      child: _CatalogMenuLabel(Icons.kitchen_outlined, 'Ingredients'),
    ),
    PopupMenuItem(
      key: ValueKey('open-settings'),
      onTap: SettingsButton._open,
      child: _CatalogMenuLabel(Icons.settings_outlined, 'Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      key: const ValueKey('more-actions'),
      tooltip: 'Show menu',
      icon: const Icon(Icons.more_vert),
      itemBuilder: _items,
    );
  }
}

class _CatalogMenuLabel extends StatelessWidget {
  const new(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]);
  }
}

class TagFilters extends SignalWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final current = selectedTags.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in tags) _TagChip(option: option, selected: current.contains(option)),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const new({required this.option, required this.selected});

  final String option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      excludeFromSemantics: true,
      onLongPress: () => _toggleTag(option),
      child: FilterChip(
        key: ValueKey('tag-$option'),
        label: Text(option.titleCase),
        selected: selected,
        onSelected: (_) => _selectTag(option),
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

class _RecipeActions extends SignalWidget {
  const new({required this.recipe, required this.popWhenDeleted});

  final Recipe recipe;
  final bool popWhenDeleted;

  @override
  Widget build(BuildContext context) {
    final recipe = recipes.findByName(this.recipe.name) ?? this.recipe;
    return Row(
      mainAxisSize: .min,
      children: [
        IconButton(
          key: const ValueKey('edit-recipe'),
          tooltip: 'Edit recipe',
          onPressed: () {
            navigator.push(
              MaterialPageRoute<void>(builder: (context) => RecipeEditor(recipe: recipe)),
            );
          },
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: const ValueKey('delete-recipe'),
          tooltip: 'Delete recipe',
          onPressed: () async {
            final confirmed = await confirmDelete(
              context,
              'Delete ${recipe.name.titleCase}?',
              'This removes the recipe from the cookbook.',
            );
            if (!confirmed || !context.mounted) return;
            await deleteRecipe(recipe.name);
            if (!context.mounted || !popWhenDeleted) return;
            navigator.pop();
          },
          icon: const Icon(Icons.delete_outlined),
        ),
      ],
    );
  }
}

class RecipeDetail extends SignalWidget {
  const new({
    required this.recipe,
    required this.showTitle,
    this.popWhenDeleted = false,
    super.key,
  });

  final Recipe recipe;
  final bool showTitle;
  final bool popWhenDeleted;

  @override
  Widget build(BuildContext context) {
    final recipe = recipes.findByName(this.recipe.name) ?? this.recipe;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    String? previousGroup;
    final children = <Widget>[
      if (showTitle) ...[
        Row(
          crossAxisAlignment: .start,
          children: [
            Expanded(child: Text(recipe.name.titleCase, style: textTheme.headlineMedium)),
            _RecipeActions(recipe: recipe, popWhenDeleted: popWhenDeleted),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Text(recipe.subtitle, style: textTheme.bodyMedium),
      const SizedBox(height: 24),
      Text('Ingredients', style: textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final (index, line) in recipe.lines.indexed) ...[
        if (line.group != previousGroup)
          if (previousGroup = line.group case final group?)
            Padding(
              padding: const .only(top: 8, bottom: 4),
              child: Text(group.titleCase, style: textTheme.titleSmall),
            ),
        _IngredientTile(key: ValueKey('ingredient-$index'), line: line),
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
        _RecipeNutrition(recipe: recipe),
      ],
    ];

    return Theme(
      key: const ValueKey('recipe-detail'),
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      child: ListView(
        key: ValueKey(recipe.name),
        padding: const .fromLTRB(20, 16, 20, 32),
        children: children,
      ),
    );
  }
}

class _RecipeNutrition extends SignalWidget {
  const new({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    if (!showNutrition.value) return const SizedBox.shrink();
    return Padding(padding: const .only(top: 16), child: NutritionLabel(recipe));
  }
}

class _IngredientTile extends SignalStatefulWidget {
  const new({required this.line, super.key});

  final RecipeLine line;

  @override
  State<_IngredientTile> createState() => _IngredientTileState();
}

class _IngredientTileState extends State<_IngredientTile>
    with AutomaticKeepAliveClientMixin<_IngredientTile> {
  final _checked = signal(false);

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _checked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final checked = _checked.value;
    final text = widget.line.display(unitNames.value);
    TextStyle? style;
    if (checked) style = TextStyle(color: ColorScheme.of(context).onSurface.withValues(alpha: 0.5));

    return CheckboxListTile(
      value: checked,
      onChanged: (_) => _checked.value = !_checked.value,
      overlayColor: .all(Colors.transparent),
      controlAffinity: .leading,
      contentPadding: .zero,
      visualDensity: .compact,
      dense: true,
      horizontalTitleGap: 4,
      minVerticalPadding: 0,
      titleAlignment: .top,
      title: Text(text, style: style),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const new({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    if (!recipe.servingsSpecified) return _Stat(label: 'Recipe', price: recipe.totalPrice);

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
    final textTheme = TextTheme.of(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(label, style: textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(price.toString(), style: textTheme.headlineSmall),
      ],
    );
  }
}

extension RecipeSubtitle on Recipe {
  String get subtitle {
    final Recipe(:tags, :servings, :servingsSpecified) = this;
    final label = tags.map((tag) => tag.titleCase).join(', ');
    if (!servingsSpecified) return label;
    final noun = servings == 1 ? 'serving' : 'servings';
    final count = '${servings.plainNumber} $noun';
    if (label.isEmpty) return count;
    return '$label · $count';
  }
}

extension TitleCase on String {
  String get titleCase {
    return split(' ')
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
}

final _directionMarkup = RegExp(r'\*\*(.+?)\*\*|\[(.+?)\]\([^)]*\)');

TextSpan _directionSpan(String source) {
  final text = source.replaceAll('<br>', '\n').trim();
  final children = <TextSpan>[];
  var index = 0;
  for (final match in _directionMarkup.allMatches(text)) {
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

void _cancel() => navigator.pop();
void _confirm() => navigator.pop(true);

Future<bool> confirmDelete(BuildContext context, String title, String message) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: const [
        TextButton(onPressed: _cancel, child: Text('Cancel')),
        TextButton(key: ValueKey('confirm-delete'), onPressed: _confirm, child: Text('Delete')),
      ],
    ),
  );
  return answer ?? false;
}
