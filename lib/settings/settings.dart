import 'dart:convert';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signal_widgets/signal_widgets.dart';

import 'package:offline_recipes/catalog/catalog.dart';
import 'package:offline_recipes/catalog_view/catalog_view.dart';
import 'package:offline_recipes/measure.dart';

part 'src/page.dart';

enum ListPrice { serving, recipe, hidden }

/// A half tablespoon, such as 1/2 or 1 1/2.
///
/// Any other fraction of a tablespoon is shown in teaspoons.
enum HalfTablespoons {
  /// Stays in tablespoons. 1/2 tablespoon stays 1/2 tablespoon.
  tablespoons,

  /// Shown in teaspoons. 1/2 tablespoon is 1 1/2 teaspoons.
  teaspoons,
}

/// An eighth of a cup.
enum EighthCup {
  /// Shown as 1/8 cup.
  cup,

  /// Shown as 2 tablespoons.
  tablespoons,
}

/// Smallest teaspoon to display: a sixteenth, an eighth, or a quarter.
enum SmallestAmount { sixteenth, eighth, quarter }

enum TextSize {
  small(0.85),
  normal(1),
  large(1.25);

  new(this.factor);

  final double factor;
}

/// Default color-scheme hue, in degrees.
const defaultHue = 27.0;
const _seedHsv = HSVColor.fromAHSV(1, defaultHue, 1, 1);

/// Fully saturated seed at [hue].
Color colorForHue(double hue) => _seedHsv.withHue(ui.clampDouble(hue, 0, 360)).toColor();

final themeMode = PersistedEnumSignal<ThemeMode>(.system, 'themeMode', ThemeMode.values);
final colorSchemeHue = PersistedDoubleSignal(defaultHue, 'colorSchemeHue');

/// Hue the theme and the slider show. Saved to [colorSchemeHue] when the pointer lifts.
final _previewHue = signal(colorSchemeHue.peek());
final Computed<Color> colorSchemeSeed = computed(() => colorForHue(_previewHue.value));

/// Saved tag hues, in degrees. A missing tag uses [defaultHueForTag].
final tagHues = TagHues();

/// Hue a slider is dragging. Saved to [tagHues] when the pointer lifts.
final _tagHuePreview = signal<({String tag, double hue})?>(null);

/// Hue of [tag], in degrees, including a drag that has not been saved yet.
double hueForTag(String tag) {
  final preview = _tagHuePreview.value;
  if (preview != null && preview.tag == tag) {
    return ui.clampDouble(preview.hue, 0, 360);
  }
  return ui.clampDouble(tagHues[tag] ?? defaultHueForTag(tag), 0, 360);
}

/// Hue for a tag nobody has recolored.
///
/// Mixed from [tag]'s code units, so it stays put across restarts and a new tag does not recolor
/// the others.
@visibleForTesting
double defaultHueForTag(String tag) {
  // Fold on every step so the mix stays an exact integer on the web.
  var hash = 0;
  for (final unit in tag.codeUnits) {
    hash = (hash * 31 + unit) % 1000003;
  }
  // 289 is coprime with 360, so this walks the wheel instead of leaving nearby hashes nearby.
  return ((hash * 289) % 360).toDouble();
}

class TagHues extends MapSignal<String, double> with PersistedSignalMixin<Map<String, double>> {
  new() : super(<String, double>{});

  @override
  final String key = 'tagHues';

  @override
  final SignalsKeyValueStore store = SignalsKeyValueStore.defaultStore;

  @override
  Map<String, double> decode(String value) {
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return {};
    }
    if (decoded is! Map) return {};

    return <String, double>{
      for (final entry in decoded.entries)
        if (entry case MapEntry(:final String key, :final num value) when value.isFinite)
          key: value.toDouble(),
    };
  }

  @override
  bool set(Map<String, double> val, {bool force = false}) {
    final changed = super.set(val, force: force);

    // Map writes notify through set, so persist here once the stored value is loaded.
    if (loaded && changed) save(val).ignore();
    return changed;
  }
}

final unitNames = PersistedEnumSignal<UnitNames>(.full, 'unitNames', UnitNames.values);
final halfTablespoons = PersistedEnumSignal<HalfTablespoons>(
  .tablespoons,
  'halfTablespoons',
  HalfTablespoons.values,
);
final eighthCup = PersistedEnumSignal<EighthCup>(.cup, 'eighthCup', EighthCup.values);
final smallestAmount = PersistedEnumSignal<SmallestAmount>(
  .eighth,
  'smallestAmount',
  SmallestAmount.values,
);
final listPrice = PersistedEnumSignal<ListPrice>(.serving, 'listPrice', ListPrice.values);
final textSize = PersistedEnumSignal<TextSize>(.normal, 'textSize', TextSize.values);
final showNutrition = PersistedBoolSignal(true, 'showNutrition');

const _animatedTheme = Duration(milliseconds: 200);

/// How long a theme change takes.
///
/// A hue preview sets this to zero so the theme tracks the thumb. The slider restores it when the
/// pointer lifts.
Duration themeAnimationDuration = _animatedTheme;

SharedPreferences? _preferences;

/// SharedPreferences backing for the settings signals.
///
/// [loadSettings] attaches the instance. Until then, a read returns null and a write is skipped.
/// Attaching the instance does not reload. [loadSettings] calls init on each signal after that.
class _PreferencesStore implements SignalsKeyValueStore {
  const new();

  @override
  Future<String?> getItem(String key) => .value(_preferences?.getString(key));

  @override
  Future<void> setItem(String key, String value) async => _preferences?.setString(key, value);

  @override
  Future<void> removeItem(String key) async => _preferences?.remove(key);
}

Future<void> loadSettings() async {
  _preferences = await SharedPreferences.getInstance();
  SignalsKeyValueStore.defaultStore = const _PreferencesStore();
  await (
    themeMode.init(),
    colorSchemeHue.init(),
    tagHues.init(),
    unitNames.init(),
    halfTablespoons.init(),
    eighthCup.init(),
    smallestAmount.init(),
    listPrice.init(),
    textSize.init(),
  ).wait;
  await showNutrition.init();
}

@visibleForTesting
void debugResetSettings() {
  _preferences = null;
  themeAnimationDuration = _animatedTheme;
  themeMode.value = .system;
  colorSchemeHue.value = defaultHue;
  _previewHue.value = colorSchemeHue.value;
  _tagHuePreview.value = null;
  tagHues.clear();
  unitNames.value = .full;
  halfTablespoons.value = .tablespoons;
  eighthCup.value = .cup;
  smallestAmount.value = .eighth;
  listPrice.value = .serving;
  textSize.value = .normal;
  showNutrition.value = true;
}
