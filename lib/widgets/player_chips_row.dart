import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/player_color.dart';
import 'ludo_colors.dart';
import 'piece_avatar.dart';

/// A slim, always-visible grid showing every player at a glance -- the
/// active player's chip is emphasized (tinted toward their own color, a
/// glow ring, bold name, slight lift) so whose turn it is reads without a
/// separate banner.
///
/// Capped at 2 chips per row (wrapping to a second row for 3-4 players)
/// rather than squeezing all of them into one row -- fitting 4 chips
/// (avatar + name each) side by side left too little width per chip and
/// pushed names past the screen edge.
class PlayerChipsRow extends StatelessWidget {
  final List<LudoPlayer> players;
  final PlayerColor activeColor;

  const PlayerChipsRow({super.key, required this.players, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    final rows = <List<LudoPlayer>>[
      for (var i = 0; i < players.length; i += 2)
        players.sublist(i, (i + 2 > players.length) ? players.length : i + 2),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          for (final row in rows) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final player in row) ...[
                  _PlayerChip(player: player, isActive: player.color == activeColor),
                  if (player != row.last) const SizedBox(width: 10),
                ],
              ],
            ),
            if (row != rows.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

/// A compact glossy pill, in the same bevel language as the dice/pieces.
/// Inactive chips sit as a neutral dark-navy pill; the active player's chip
/// tints toward their own color (a darkened gradient + a colored glow ring)
/// instead of a flat colored border, and lifts slightly off the row.
class _PlayerChip extends StatelessWidget {
  final LudoPlayer player;
  final bool isActive;

  const _PlayerChip({required this.player, required this.isActive});

  static const _neutralTop = Color(0xFF2C3E64);
  static const _neutralBottom = Color(0xFF1A2740);

  @override
  Widget build(BuildContext context) {
    final color = player.color.material;
    final activeTop = Color.lerp(color, Colors.black, 0.45)!;
    final activeBottom = Color.lerp(color, Colors.black, 0.72)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      transform: isActive ? (Matrix4.identity()..translateByDouble(0.0, -1.5, 0.0, 1.0)) : Matrix4.identity(),
      padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive ? [activeTop, activeBottom] : [_neutralTop, _neutralBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: isActive ? 0.15 : 0.12),
            blurRadius: 3,
            blurStyle: BlurStyle.inner,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.4 : 0.35),
            blurRadius: 5,
            blurStyle: BlurStyle.inner,
            offset: const Offset(0, -3),
          ),
          if (isActive)
            BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 1.5)
          else
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PieceAvatar(
            color: player.color,
            size: 20,
            photoPath: player.photoPath,
            initial: player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
            isBot: player.isBot,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
