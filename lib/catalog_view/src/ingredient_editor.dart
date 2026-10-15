part of '../catalog_view.dart';

void _openIngredientEditor([Ingredient? ingredient]) {
  navigator.push(
    MaterialPageRoute<void>(builder: (context) => IngredientEditor(ingredient: ingredient)),
  );
}

class IngredientListPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredients'),
        actions: const [
          IconButton(
            key: ValueKey('new-ingredient'),
            tooltip: 'New ingredient',
            onPressed: _openIngredientEditor,
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const .fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const ValueKey('ingredient-search'),
              controller: ingredients.controller,
              decoration: InputDecoration(
                hintText: 'Search ingredients',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: .circular(28)),
                isDense: true,
              ),
            ),
          ),
          const Expanded(child: _IngredientMatches()),
        ],
      ),
    );
  }
}

class _IngredientMatches extends SignalWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final matching = ingredients.matching.value;
    if (matching.isEmpty) return const Center(child: Text('No ingredients match.'));
    return ListView.separated(
      key: const ValueKey('ingredient-list'),
      itemCount: matching.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ingredient = matching[index];
        return ListTile(
          key: ValueKey('ingredient-${ingredient.name}'),
          title: Text(ingredient.name.titleCase),
          subtitle: Text('${ingredient.servingSizeText} · ${ingredient.totalPrice}'),
          onTap: () => _openIngredientEditor(ingredient),
        );
      },
    );
  }
}

class IngredientEditor extends SignalStatefulWidget {
  const new({this.ingredient, super.key});

  final Ingredient? ingredient;

  @override
  State<IngredientEditor> createState() => _IngredientEditorState();
}

class _IngredientEditorState extends State<IngredientEditor> {
  late final TextEditingController _name;
  late final TextEditingController _servingSize;
  late final TextEditingController _servings;
  late final TextEditingController _price;
  late final TextEditingController _calories;
  final _nutrients = listSignal(<_NutrientField>[]);
  final _error = signal<String?>(null);

  @override
  void initState() {
    super.initState();
    final ingredient = widget.ingredient;
    _name = TextEditingController(text: ingredient?.name);
    _servingSize = TextEditingController(text: ingredient?.servingSizeText);
    _servings = TextEditingController(text: ingredient?.servings.plainNumber);
    _price = TextEditingController(text: ingredient?.totalPrice.dollars.toStringAsFixed(2));
    _calories = TextEditingController(text: ingredient?.servingNutrition.calories.plainNumber);
    if (ingredient != null) {
      _nutrients.addAll(ingredient.measurementText.entries.map(_NutrientField.new));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _servingSize.dispose();
    _servings.dispose();
    _price.dispose();
    _calories.dispose();
    for (final nutrient in _nutrients.peek()) {
      nutrient.dispose();
    }
    _nutrients.dispose();
    _error.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final Ingredient ingredient;
    try {
      ingredient = Ingredient.fromEditor(
        name: _name.text,
        servingSize: _servingSize.text,
        servings: _servings.text,
        price: _price.text,
        calories: _calories.text,
        nutrients: [
          for (final nutrient in _nutrients.peek())
            (name: nutrient.name.text, amount: nutrient.amount.text),
        ],
      );
      await saveIngredient(ingredient, previousName: widget.ingredient?.name);
    } on FormatException catch (error) {
      if (!mounted) return;
      _error.value = error.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _delete() async {
    final ingredient = widget.ingredient;
    if (ingredient == null) return;
    final confirmed = await confirmDelete(
      context,
      'Delete ${ingredient.name.titleCase}?',
      'Recipes that use it lose its price and nutrition.',
    );
    if (!confirmed || !mounted) return;
    await deleteIngredient(ingredient.name);
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _error.value;
    final existing = widget.ingredient;
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'New ingredient' : 'Edit ingredient'),
        actions: [
          if (existing != null)
            IconButton(
              key: const ValueKey('delete-ingredient'),
              tooltip: 'Delete ingredient',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outlined),
            ),
          TextButton(
            key: const ValueKey('save-ingredient'),
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
                key: const ValueKey('ingredient-name'),
                controller: _name,
                textInputAction: .next,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ingredient-serving-size'),
                controller: _servingSize,
                textInputAction: .next,
                decoration: const InputDecoration(
                  labelText: 'Serving size',
                  helperText: 'For example, 1 cup or 100 g.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ingredient-servings'),
                controller: _servings,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: .next,
                decoration: const InputDecoration(
                  labelText: 'Servings per container',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ingredient-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: .next,
                decoration: const InputDecoration(
                  labelText: 'Container price',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ingredient-calories'),
                controller: _calories,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: .next,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  helperText: 'Calories in one serving.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Nutrients', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final nutrient in _nutrients) ...[
                Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: ObjectKey(nutrient.name),
                        controller: nutrient.name,
                        decoration: const InputDecoration(
                          labelText: 'Nutrient',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: ObjectKey(nutrient.amount),
                        controller: nutrient.amount,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: '3 g',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove nutrient',
                      onPressed: () {
                        nutrient.dispose();
                        _nutrients.remove(nutrient);
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
                  key: const ValueKey('add-nutrient'),
                  onPressed: () => _nutrients.add(_NutrientField()),
                  icon: const Icon(Icons.add),
                  label: const Text('Add nutrient'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientField {
  new([MapEntry<String, String>? entry])
    : name = TextEditingController(text: entry?.key),
      amount = TextEditingController(text: entry?.value);

  final TextEditingController name;
  final TextEditingController amount;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}
