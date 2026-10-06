import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signal_widgets/signal_widgets.dart';

import 'catalog.dart';
import 'catalog_view.dart';

void main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  SignalsObserver.instance = null;
  await loadCatalog();
  runApp(const App());
}

class App extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recipes',
      navigatorKey: navKey,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8A5A34), brightness: .light),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF8A5A34), brightness: .dark),
      home: const CatalogPage(),
    );
  }
}
