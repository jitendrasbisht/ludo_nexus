import 'package:flutter/material.dart';

/// Wraps [child] with the decorative ludo-themed background (watercolor-blue
/// wash with faint board/dice watermarks) shared by the setup and game
/// screens, in place of the default plain Scaffold background.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background/ludo_background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
