import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/theme_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeStore.load();
  runApp(const LudoApp());
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo Nexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1E88E5), useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}
