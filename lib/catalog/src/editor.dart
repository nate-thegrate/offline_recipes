part of '../catalog.dart';

final _calorieWord = RegExp(r'cal', caseSensitive: false);

List<Object> _ingredientItems(List<RecipeLine> lines) {
  final items = <Object>[];
  String? group;
  List<String>? grouped;
  void flush() {
    final name = group;
    final texts = grouped;
    if (name == null || texts == null) return;
    items.add({name: texts});
    group = null;
    grouped = null;
  }

  for (final line in lines) {
    if (line.group == null) {
      flush();
      items.add(line.text);
      continue;
    }
    if (line.group != group) {
      flush();
      group = line.group;
      grouped = <String>[];
    }
    grouped!.add(line.text);
  }
  flush();
  return items;
}

String directionForField(String stored) => stored.replaceAll('<br>', '\n');

String directionFromField(String field) {
  final stored = field.replaceAll('\n', '<br>');
  if (stored.replaceAll('<br>', '').trim().isEmpty) return '';
  return stored;
}

({String text, Measure measure}) _servingMeasure(String servingSize) {
  final text = servingSize.trim();
  if (text.isEmpty) {
    throw const FormatException('Enter a serving size, such as 1 cup');
  }
  try {
    return (text: text, measure: Measure.parseExact(text));
  } on FormatException {
    throw const FormatException('Enter a serving size, such as 1 cup');
  }
}

Map<String, String> _nutrientAmounts(List<({String name, String amount})> nutrients) {
  final amounts = <String, String>{};
  for (final (:name, :amount) in nutrients) {
    final nutrientName = name.trim();
    final nutrientAmount = amount.trim();
    if (nutrientName.isEmpty && nutrientAmount.isEmpty) continue;
    if (nutrientName.isEmpty || nutrientAmount.isEmpty) {
      throw const FormatException('Enter both a nutrient name and an amount');
    }
    if (nutrientName.toLowerCase() == 'calories') {
      throw const FormatException('Enter calories in the calories field');
    }
    if (amounts.containsKey(nutrientName)) {
      throw FormatException('$nutrientName is listed twice');
    }
    amounts[nutrientName] = nutrientAmount;
  }
  return amounts;
}

List<RecipeLine> _linesFromText(String text, List<Ingredient> pantry) {
  final lines = <RecipeLine>[];
  final index = _indexByName(pantry);
  String? group;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (_isGroupHeader(line)) {
      group = line.substring(0, line.length - 1).trim();
      continue;
    }
    lines.add(RecipeLine.parse(line, pantry, group: group, index: index));
  }
  return lines;
}

bool _isGroupHeader(String line) {
  if (!line.endsWith(':')) return false;
  final name = line.substring(0, line.length - 1).trim();
  if (name.isEmpty) return false;
  return ParsedAmount.tryParse(name) == null;
}

String _requiredName(String text) {
  final name = text.trim();
  if (name.isEmpty) throw const FormatException('Enter a name');
  return name;
}

double _positiveNumber(String text, String label) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) throw FormatException('Enter $label');
  final parsed = double.tryParse(trimmed);
  if (parsed == null) throw FormatException('Enter $label as a number');
  if (parsed <= 0) throw FormatException('$label must be greater than zero');
  return parsed;
}

double _price(String text) {
  final trimmed = text.trim().replaceAll(r'$', '').replaceAll(',', '');
  if (trimmed.isEmpty) throw const FormatException('Enter a container price');
  final parsed = double.tryParse(trimmed);
  if (parsed == null) throw const FormatException('Enter a container price');
  if (parsed < 0) throw const FormatException('Price cannot be negative');
  return parsed;
}

double _calories(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  final number = trimmed.replaceAll(',', '').replaceAll(_calorieWord, '').trim();
  final parsed = double.tryParse(number);
  if (parsed == null) throw const FormatException('Enter calories as a number');
  if (parsed < 0) throw const FormatException('Calories cannot be negative');
  return parsed;
}
