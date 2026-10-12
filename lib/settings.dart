import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signal_widgets/signal_widgets.dart';

import 'measure.dart';

enum ListPrice { serving, recipe, hidden }

enum TextSize {
  small(0.85),
  normal(1),
  large(1.25);

  new(this.factor);

  final double factor;
}

const defaultSeed = Color(0xFF8A5A34);

final HSVColor _seedHsv = HSVColor.fromColor(defaultSeed);

/// Hue of [defaultSeed], in degrees.
final double defaultHue = _seedHsv.hue;

/// Seed color at [hue], keeping the saturation and value of [defaultSeed].
Color colorForHue(double hue) {
  if (hue == defaultHue) return defaultSeed;
  return _seedHsv.withHue(hue.clamp(0, 360).toDouble()).toColor();
}

final _preferencesStore = _PreferencesStore();

final themeMode = PersistedEnumSignal<ThemeMode>(
  .system,
  'themeMode',
  ThemeMode.values,
  store: _preferencesStore,
);
final colorSchemeHue = PersistedDoubleSignal(
  defaultHue,
  'colorSchemeHue',
  store: _preferencesStore,
);

/// Hue the theme and the slider show. Saved to [colorSchemeHue] when the pointer lifts.
final _previewHue = signal(defaultHue);

final Computed<Color> colorSchemeSeed = computed(() => colorForHue(_previewHue.value));
final unitNames = PersistedEnumSignal<UnitNames>(
  .full,
  'unitNames',
  UnitNames.values,
  store: _preferencesStore,
);
final listPrice = PersistedEnumSignal<ListPrice>(
  .serving,
  'listPrice',
  ListPrice.values,
  store: _preferencesStore,
);
final textSize = PersistedEnumSignal<TextSize>(
  .normal,
  'textSize',
  TextSize.values,
  store: _preferencesStore,
);
final showNutrition = PersistedBoolSignal(true, 'showNutrition', store: _preferencesStore);

const _animatedTheme = Duration(milliseconds: 200);

/// How long a theme change takes.
///
/// A hue preview sets this to zero so the theme tracks the thumb. The slider restores it when the
/// pointer lifts.
Duration themeAnimationDuration = _animatedTheme;

/// SharedPreferences backing for the settings signals.
///
/// [loadSettings] attaches the instance. Until then, a read returns null and a write is skipped.
/// Attaching the instance does not reload. [loadSettings] calls init on each signal after that.
class _PreferencesStore implements SignalsKeyValueStore {
  SharedPreferences? _preferences;

  @override
  Future<String?> getItem(String key) => Future.value(_preferences?.getString(key));

  @override
  Future<void> setItem(String key, String value) async => _preferences?.setString(key, value);

  @override
  Future<void> removeItem(String key) async => _preferences?.remove(key);
}

Future<void> loadSettings() async {
  _preferencesStore._preferences = await SharedPreferences.getInstance();
  await (
    themeMode.init(),
    colorSchemeHue.init(),
    unitNames.init(),
    listPrice.init(),
    textSize.init(),
    showNutrition.init(),
  ).wait;
  _previewHue.value = colorSchemeHue.value;
}

@visibleForTesting
void debugResetSettings() {
  _preferencesStore._preferences = null;
  themeAnimationDuration = _animatedTheme;
  themeMode.value = .system;
  colorSchemeHue.value = defaultHue;
  _previewHue.value = colorSchemeHue.value;
  unitNames.value = .full;
  listPrice.value = .serving;
  textSize.value = .normal;
  showNutrition.value = true;
}

class SettingsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const .fromLTRB(0, 8, 0, 24),
            children: [
              _Choice<ThemeMode>(
                title: 'Appearance',
                controlKey: 'theme-mode',
                setting: themeMode,
                segments: const [
                  ButtonSegment(value: .system, label: Text('System')),
                  ButtonSegment(value: .light, label: Text('Light')),
                  ButtonSegment(value: .dark, label: Text('Dark')),
                ],
              ),
              const _HueSlider(),
              _Choice<TextSize>(
                title: 'Text size',
                subtitle: 'Scales recipe text. The nutrition label stays the same size.',
                controlKey: 'text-size',
                setting: textSize,
                segments: const [
                  ButtonSegment(value: .small, label: Text('Small')),
                  ButtonSegment(value: .normal, label: Text('Default')),
                  ButtonSegment(value: .large, label: Text('Large')),
                ],
              ),
              _Choice<UnitNames>(
                title: 'Ingredient units',
                subtitle: '1 tablespoon · 1 tbsp · 1 T',
                controlKey: 'unit-names',
                setting: unitNames,
                segments: const [
                  ButtonSegment(value: .full, label: Text('Full')),
                  ButtonSegment(value: .short, label: Text('Short')),
                  ButtonSegment(value: .superShort, label: Text('Tiny')),
                ],
              ),
              _Choice<ListPrice>(
                title: 'Recipe list',
                subtitle: 'Price beside a priced recipe.',
                controlKey: 'list-price',
                setting: listPrice,
                segments: const [
                  ButtonSegment(value: .serving, label: Text('Serving')),
                  ButtonSegment(value: .recipe, label: Text('Recipe')),
                  ButtonSegment(value: .hidden, label: Text('Hidden')),
                ],
              ),
              SignalBuilder(
                builder: (context) => Padding(
                  padding: const .only(top: 8),
                  child: SwitchListTile(
                    key: const ValueKey('show-nutrition'),
                    title: const Text('Nutrition facts'),
                    subtitle: const Text('Show the label on a priced recipe.'),
                    value: showNutrition.value,
                    onChanged: (show) => showNutrition.value = show,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const new({
    required this.title,
    required this.controlKey,
    required this.setting,
    required this.segments,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String controlKey;
  final Signal<T> setting;
  final List<ButtonSegment<T>> segments;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      subtitle: subtitle,
      child: SignalBuilder(
        builder: (context) => SegmentedButton<T>(
          key: ValueKey(controlKey),
          expandedInsets: .zero,
          showSelectedIcon: false,
          segments: segments,
          selected: {setting.value},
          onSelectionChanged: (selected) => setting.value = selected.single,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.child, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final variant = colorScheme.onSurfaceVariant;
    final titleStyle = textTheme.titleMedium;
    return Padding(
      padding: const .fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (trailing case final trailing?)
            Row(
              children: [
                Text(title, style: titleStyle),
                const Spacer(),
                Text(trailing, style: titleStyle?.copyWith(color: variant)),
              ],
            )
          else
            Text(title, style: titleStyle),
          if (subtitle case final subtitle?) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: variant)),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _HueSlider extends SignalWidget {
  const new();

  static void _preview(double hue) {
    themeAnimationDuration = Duration.zero;
    _previewHue.value = hue;
  }

  static void _release(double hue) {
    _preview(hue);
    colorSchemeHue.value = hue;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      themeAnimationDuration = _animatedTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hue = _previewHue.value;
    final scheme = ColorScheme.of(context);
    final seed = colorForHue(hue);
    return _Section(
      title: 'Color',
      trailing: '${hue.round()}°',
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 12,
          // A transparent track color collapses the track rect.
          activeTrackColor: seed,
          inactiveTrackColor: seed,
          thumbColor: seed,
          overlayColor: seed.withValues(alpha: 0.16),
          trackShape: _HueTrackShape(scheme.outlineVariant),
          thumbShape: const _HueThumbShape(),
        ),
        child: Slider(
          key: const ValueKey('color-hue'),
          padding: .zero,
          max: 360,
          value: hue,
          semanticFormatterCallback: (value) => '${value.round()} degrees',
          onChanged: _preview,
          onChangeEnd: _release,
        ),
      ),
    );
  }
}

class _HueTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const new(this.border);

  final Color border;

  static final _colors = [for (var hue = 0.0; hue <= 360; hue += 15) colorForHue(hue)];

  static final _rtlColors = _colors.reversed.toList(growable: false);

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (rect.isEmpty) return;
    final colors = textDirection == .rtl ? _rtlColors : _colors;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    context.canvas.drawRRect(
      rrect,
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );
    context.canvas.drawRRect(
      rrect,
      Paint()
        ..style = .stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }
}

class _HueThumbShape extends RoundSliderThumbShape {
  const new();

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final paint = Paint()..color = Colors.black;
    final canvas = context.canvas;
    canvas.drawCircle(center, enabledThumbRadius + 2, paint);
    canvas.drawCircle(center, enabledThumbRadius + 1, paint..color = Colors.white);
    canvas.drawCircle(center, enabledThumbRadius, paint..color = sliderTheme.thumbColor!);
  }
}
