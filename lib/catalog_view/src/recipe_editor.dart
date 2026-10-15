part of '../catalog_view.dart';

class RecipeEditor extends SignalStatefulWidget {
  const new({this.recipe, super.key});

  final Recipe? recipe;

  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
  late final TextEditingController _name;
  late final TextEditingController _tags;
  late final TextEditingController _servings;
  late final TextEditingController _ingredients;
  late final Signal<bool> _calculate;
  late final ListSignal<TextEditingController> _steps;
  final _error = signal<String?>(null);

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _name = TextEditingController(text: recipe?.name);
    _tags = TextEditingController(text: recipe?.tags.join(', '));
    _servings = TextEditingController(text: recipe?.specifiedServings);
    _ingredients = TextEditingController(text: recipe?.ingredientLinesText);
    _calculate = signal(recipe?.calculatesNutrition ?? true);
    final directions = recipe?.directions;
    _steps = listSignal([
      if (directions == null || directions.isEmpty)
        TextEditingController()
      else
        for (final direction in directions)
          TextEditingController(text: directionForField(direction)),
    ]);
  }

  @override
  void dispose() {
    _name.dispose();
    _tags.dispose();
    _servings.dispose();
    _ingredients.dispose();
    for (final step in _steps.peek()) {
      step.dispose();
    }
    _steps.dispose();
    _calculate.dispose();
    _error.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final previous = widget.recipe?.name;
    final Recipe recipe;
    try {
      recipe = Recipe.fromEditor(
        name: _name.text,
        tags: _tags.text,
        servings: _servings.text,
        calculatesNutrition: _calculate.peek(),
        ingredientText: _ingredients.text,
        directions: [for (final step in _steps.peek()) directionFromField(step.text)],
      );
      await saveRecipe(recipe, previousName: previous);
    } on FormatException catch (error) {
      if (!mounted) return;
      _error.value = error.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    navigator.pop();
    if (previous != null && previous != recipe.name && navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _error.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'New recipe' : 'Edit recipe'),
        actions: [
          TextButton(
            key: const ValueKey('save-recipe'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            key: const ValueKey('editor-form'),
            padding: const .fromLTRB(16, 16, 16, 32),
            children: [
              if (message != null) ...[
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: const ValueKey('recipe-name'),
                controller: _name,
                textInputAction: .next,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('recipe-tags'),
                controller: _tags,
                textInputAction: .next,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  helperText: 'Separate tags with commas.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('recipe-servings'),
                controller: _servings,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: .next,
                decoration: const InputDecoration(
                  labelText: 'Servings',
                  helperText: 'Leave blank when the recipe is one batch.',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('recipe-calculate'),
                contentPadding: .zero,
                title: const Text('Calculate nutrition & price'),
                value: _calculate.value,
                onChanged: (value) => _calculate.value = value,
              ),
              TextField(
                key: const ValueKey('recipe-ingredients'),
                controller: _ingredients,
                minLines: 8,
                maxLines: null,
                textCapitalization: .sentences,
                decoration: const InputDecoration(
                  labelText: 'Ingredients',
                  alignLabelWithHint: true,
                  helperText: 'One ingredient per line. A line ending in : starts a group.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Directions', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final (index, step) in _steps.indexed) ...[
                Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: index == 0 ? const ValueKey('recipe-directions') : ObjectKey(step),
                        controller: step,
                        minLines: 2,
                        maxLines: null,
                        textCapitalization: .sentences,
                        decoration: InputDecoration(
                          labelText: 'Step ${index + 1}',
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove step',
                      onPressed: () {
                        step.dispose();
                        _steps.remove(step);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: .centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('add-direction'),
                  onPressed: () => _steps.add(TextEditingController()),
                  icon: const Icon(Icons.add),
                  label: const Text('Add step'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
