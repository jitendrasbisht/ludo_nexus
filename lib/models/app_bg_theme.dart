import 'package:flutter/material.dart';

/// The background choices a player can pick between (Setup screen AppBar).
/// Each carries its own background image and a matching AppBar color so
/// the two never clash. [kidsCartoon] and [kidsNight] both trigger the
/// comic-outline UI variant (see [isKids]) on the setup/game screen chrome
/// (slot cards, buttons, toggles, player chips) instead of the classic
/// glossy-bevel one used by [navy]/[sunset].
enum AppBgTheme { navy, sunset, kidsCartoon, kidsNight }

extension AppBgThemeX on AppBgTheme {
  String get label {
    switch (this) {
      case AppBgTheme.navy:
        return 'Classic';
      case AppBgTheme.sunset:
        return 'Sunset';
      case AppBgTheme.kidsCartoon:
        return 'Cartoon';
      case AppBgTheme.kidsNight:
        return 'Night Sky';
    }
  }

  String get assetPath {
    switch (this) {
      case AppBgTheme.navy:
        return 'assets/background/ludo_background.png';
      case AppBgTheme.sunset:
        return 'assets/background/ludo_background_sunset.png';
      case AppBgTheme.kidsCartoon:
        return 'assets/background/ludo_background_kids.png';
      case AppBgTheme.kidsNight:
        return 'assets/background/ludo_background_kids_night.png';
    }
  }

  Color get appBarColor {
    switch (this) {
      case AppBgTheme.navy:
        return const Color(0xFF2A3E66);
      case AppBgTheme.sunset:
        return const Color(0xFFC23B6B);
      case AppBgTheme.kidsCartoon:
        return const Color(0xFF3FA9DB);
      case AppBgTheme.kidsNight:
        return const Color(0xFF3A2F6E);
    }
  }

  /// A representative solid color for each theme's swatch in the picker UI.
  Color get swatchColor {
    switch (this) {
      case AppBgTheme.navy:
        return const Color(0xFF2A3E66);
      case AppBgTheme.sunset:
        return const Color(0xFFE85D8A);
      case AppBgTheme.kidsCartoon:
        return const Color(0xFF6EC6FF);
      case AppBgTheme.kidsNight:
        return const Color(0xFF5A3A7A);
    }
  }

  bool get isKids => this == AppBgTheme.kidsCartoon || this == AppBgTheme.kidsNight;
}
