import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:material_ui/material_ui.dart';

import 'catalog.dart';
import 'catalog_view.dart';

void main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  await loadCatalog();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recipes',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8A5A34), brightness: .light),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF8A5A34), brightness: .dark),
      home: const CatalogPage(),
    );
  }
}
