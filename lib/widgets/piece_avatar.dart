import 'dart:io';

import 'package:flutter/material.dart';

import '../models/player_color.dart';

/// A glossy 3D game token (per-color PNG asset) with the player's photo,
/// a bot glyph, or their initial overlaid on top when relevant. Occupies
/// exactly a [size] x [size] box so swapping the flat-square look for this
/// token never shifts anything positioned around it.
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

  static const Map<PlayerColor, String> _tokenAssets = {
    PlayerColor.red: 'assets/pieces/red.png',
    PlayerColor.green: 'assets/pieces/green.png',
    PlayerColor.yellow: 'assets/pieces/yellow.png',
    PlayerColor.blue: 'assets/pieces/blue.png',
  };

  @override
  Widget build(BuildContext context) {
    // The badge (photo/bot/initial) sits on the token's flat top face,
    // which the generator draws at roughly 68% of the full canvas.
    final badgeSize = size * 0.62;
    // Yellow's fill is too bright for white glyphs to read against --
    // every other color is dark enough for white to hold contrast.
    final onToken = color == PlayerColor.yellow ? Colors.black87 : Colors.white;
    final glyphShadow = color == PlayerColor.yellow
        ? const Shadow(color: Colors.white70, blurRadius: 3)
        : const Shadow(color: Colors.black54, blurRadius: 3);

    Widget? badge;
    if (!isBot && photoPath != null && File(photoPath!).existsSync()) {
      badge = ClipOval(
        child: Image.file(File(photoPath!), fit: BoxFit.cover, width: badgeSize, height: badgeSize),
      );
    } else if (isBot) {
      badge = Icon(Icons.star_rounded, color: onToken, size: badgeSize * 0.78, shadows: [glyphShadow]);
    } else {
      badge = Text(
        initial,
        style: TextStyle(
          color: onToken,
          fontWeight: FontWeight.bold,
          fontSize: badgeSize * 0.55,
          shadows: [glyphShadow],
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
          shape: BoxShape.circle,
          boxShadow: highlighted
              ? [BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: size * 0.35, spreadRadius: size * 0.04)]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(_tokenAssets[color]!, width: size, height: size),
            badge,
          ],
        ),
      ),
    );
  }
}
