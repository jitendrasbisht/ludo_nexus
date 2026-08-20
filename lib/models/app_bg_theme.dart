import 'package:flutter/material.dart';

/// The background choices a player can pick between (Setup screen AppBar).
/// Each carries its own background image and a matching AppBar color so
/// the two never clash. [kidsCartoon] and [kidsNight] both trigger the
/// comic-outline UI variant (see [isKids]) on the setup/game screen chrome
/// (slot cards, buttons, toggles, player chips) instead of the classic
/// glossy-bevel one used by [navy]/[sunset]. [adventure] is a photo
/// slideshow (see AdventureSlideshowOverlay) instead of a single static
/// image -- its [assetPath] is only a fallback and isn't normally shown.
enum AppBgTheme { navy, sunset, kidsCartoon, kidsNight, adventure }

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
      case AppBgTheme.adventure:
        return 'Adventure';
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
      case AppBgTheme.adventure:
        return 'assets/background/adventure/DSCN1227.jpg';
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
      case AppBgTheme.adventure:
        return const Color(0xFF3E5C74);
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
      case AppBgTheme.adventure:
        return const Color(0xFF6E9CB8);
    }
  }

  bool get isKids => this == AppBgTheme.kidsCartoon || this == AppBgTheme.kidsNight;
}
