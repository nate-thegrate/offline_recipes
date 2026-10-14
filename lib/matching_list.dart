import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signal_widgets/signal_widgets.dart';

/// A reactive list with a search box over its current items.
class MatchingList<T> extends ListSignal<T> {
  new(this._matches) : super([]) {
    controller.addListener(() => _query.value = controller.text.trim().toLowerCase());
  }

  final controller = TextEditingController();
  final _query = signal('');

  final List<T> Function(String query) _matches;
  List<T>? _cache;

  late final matching = computed(_compute);
  List<T> _compute() {
    final next = _matches(_query.value);
    return listEquals(_cache, next) ? _cache! : _cache = next;
  }

  @override
  void dispose() {
    controller.dispose();
    _query.dispose();
    matching.dispose();
    super.dispose();
  }
}
