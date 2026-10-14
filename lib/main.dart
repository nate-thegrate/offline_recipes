import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signal_widgets/signal_widgets.dart';

import 'catalog/catalog.dart';
import 'catalog_view/catalog_view.dart';
import 'settings/settings.dart';

void main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  SignalsObserver.instance = null;
  await (loadCatalog(), loadSettings()).wait;
  await reloadCatalogEdits();
  runApp(const App());
}

class App extends SignalWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = colorSchemeSeed.value;
    final factor = textSize.value.factor;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recipes',
      navigatorKey: navKey,
      themeMode: themeMode.value,
      themeAnimationDuration: themeAnimationDuration,
      theme: ThemeData(colorSchemeSeed: seed, brightness: .light),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: .dark),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.scale(16) / 16 * factor;
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: const CatalogPage(),
    );
  }
}
