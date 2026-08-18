import 'package:flutter/material.dart';

import '../models/app_bg_theme.dart';
import '../services/theme_store.dart';

/// Wraps [child] with the decorative ludo-themed background (a gradient
/// wash with faint board/dice watermarks) shared by the splash, setup, and
/// game screens, in place of the default plain Scaffold background.
/// Reactively follows [ThemeStore.current], so switching the background
/// theme anywhere in the app updates every visible instance immediately.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeStore.current,
      builder: (context, theme, _) {
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(theme.assetPath),
              fit: BoxFit.cover,
            ),
          ),
          child: child,
        );
      },
    );
  }
}
