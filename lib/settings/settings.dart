import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signal_widgets/signal_widgets.dart';

import 'package:offline_recipes/measure.dart';

part 'src/page.dart';

enum ListPrice { serving, recipe, hidden }

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

final unitNames = PersistedEnumSignal<UnitNames>(.full, 'unitNames', UnitNames.values);
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
    unitNames.init(),
    listPrice.init(),
    textSize.init(),
    showNutrition.init(),
  ).wait;
}

@visibleForTesting
void debugResetSettings() {
  _preferences = null;
  themeAnimationDuration = _animatedTheme;
  themeMode.value = .system;
  colorSchemeHue.value = defaultHue;
  _previewHue.value = colorSchemeHue.value;
  unitNames.value = .full;
  listPrice.value = .serving;
  textSize.value = .normal;
  showNutrition.value = true;
}
