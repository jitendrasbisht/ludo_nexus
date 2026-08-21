import 'package:flutter/material.dart';

import '../models/app_bg_theme.dart';
import '../services/theme_store.dart';
import 'adventure_slideshow_overlay.dart';
import 'cartoon_cast_overlay.dart';
import 'night_cast_overlay.dart';

/// Wraps [child] with the decorative ludo-themed background (a gradient
/// wash with faint board/dice watermarks) shared by the splash, setup, and
/// game screens, in place of the default plain Scaffold background.
/// Reactively follows [ThemeStore.current], so switching the background
/// theme anywhere in the app updates every visible instance immediately.
/// The Cartoon and Night Sky kids themes additionally get an animated
/// background cast ([CartoonCastOverlay] / [NightCastOverlay]) layered
/// between the image and [child]. The Adventure theme replaces the single
/// static image entirely with a crossfading photo slideshow
/// ([AdventureSlideshowOverlay]).
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeStore.current,
      builder: (context, theme, _) {
        final isAdventure = theme == AppBgTheme.adventure;
        return Container(
          // Explicit fill regardless of theme -- without it, a Container
          // with no decoration (the Adventure case, since its background
          // comes from the slideshow overlay instead) shrinks to fit its
          // content rather than filling the screen. That was invisible
          // for the other themes (their DecorationImage forces full size
          // on its own) but left a plain white gap below shorter content
          // -- e.g. only 2 player cards -- for Adventure specifically.
          width: double.infinity,
          height: double.infinity,
          decoration: isAdventure
              ? null
              : BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(theme.assetPath),
                    fit: BoxFit.cover,
                  ),
                ),
          child: Stack(
            children: [
              if (isAdventure) const Positioned.fill(child: AdventureSlideshowOverlay()),
              if (theme == AppBgTheme.kidsCartoon) const Positioned.fill(child: CartoonCastOverlay()),
              if (theme == AppBgTheme.kidsNight) const Positioned.fill(child: NightCastOverlay()),
              child,
            ],
          ),
        );
      },
    );
  }
}
