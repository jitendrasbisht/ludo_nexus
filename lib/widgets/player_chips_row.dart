import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/player_color.dart';
import 'ludo_colors.dart';
import 'piece_avatar.dart';

/// A slim, always-visible row showing every player at a glance -- the
/// active player's chip is emphasized (bigger avatar, filled outline,
/// bold name) so whose turn it is reads without a separate banner.
class PlayerChipsRow extends StatelessWidget {
  final List<LudoPlayer> players;
  final PlayerColor activeColor;

  const PlayerChipsRow({super.key, required this.players, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          for (final player in players) ...[
            _PlayerChip(player: player, isActive: player.color == activeColor),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final LudoPlayer player;
  final bool isActive;

  const _PlayerChip({required this.player, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = player.color.material;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color : color.withValues(alpha: 0.3), width: isActive ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PieceAvatar(
            color: player.color,
            size: isActive ? 30 : 24,
            photoPath: player.photoPath,
            initial: player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
            isBot: player.isBot,
          ),
          const SizedBox(width: 6),
          Text(
            player.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? color : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
