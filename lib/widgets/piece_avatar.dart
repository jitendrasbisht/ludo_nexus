import 'dart:io';

import 'package:flutter/material.dart';

import '../models/player_color.dart';
import 'ludo_colors.dart';

/// A single square token: the player's photo cropped to a rounded square
/// with a colored ring, or a colored square with their initial when no
/// photo was chosen. Bots always show a robot glyph and never a photo.
class PieceAvatar extends StatelessWidget {
  final PlayerColor color;
  final double size;
  final String? photoPath;
  final String initial;
  final bool isBot;
  final bool highlighted;
  final VoidCallback? onTap;

  const PieceAvatar({
    super.key,
    required this.color,
    required this.size,
    this.photoPath,
    this.initial = '?',
    this.isBot = false,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ring = color.material;
    // Bright fills (yellow) need dark text/icon for contrast instead of
    // the white that works on every other, darker player color.
    final onRing = ring.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    // A glossy radial shade (light highlight toward the upper-left, darker
    // toward the edge) so the flat fallback token reads more like a
    // rounded piece than a solid color swatch.
    final glossyFill = BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 1.0,
        colors: [Color.lerp(ring, Colors.white, 0.35)!, ring, Color.lerp(ring, Colors.black, 0.18)!],
        stops: const [0.0, 0.55, 1.0],
      ),
    );

    Widget inner;
    if (!isBot && photoPath != null && File(photoPath!).existsSync()) {
      inner = Image.file(File(photoPath!), fit: BoxFit.cover, width: size, height: size);
    } else if (isBot) {
      inner = Container(
        decoration: glossyFill,
        alignment: Alignment.center,
        child: Icon(Icons.smart_toy, color: onRing, size: size * 0.55),
      );
    } else {
      inner = Container(
        decoration: glossyFill,
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: onRing,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.45,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(
            color: highlighted ? Colors.white : ring,
            width: highlighted ? size * 0.14 : size * 0.09,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: size * 0.12,
              offset: Offset(0, size * 0.04),
            ),
            if (highlighted)
              BoxShadow(color: ring.withValues(alpha: 0.9), blurRadius: size * 0.35, spreadRadius: size * 0.04),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.12),
          child: inner,
        ),
      ),
    );
  }
}
