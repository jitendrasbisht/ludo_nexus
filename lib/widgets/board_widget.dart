import 'package:flutter/material.dart';

import '../game/board_layout.dart';
import '../game/board_path.dart';
import '../models/piece.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import 'board_painter.dart';
import 'finish_crown_badge.dart';
import 'piece_avatar.dart';

/// Maps a piece's relative track position to its fractional board offset.
/// Exposed at top level so callers driving a step-by-step walk animation
/// (see GameScreen) can compute the same intermediate cells the board
/// itself would render.
Offset fractionForPiecePosition(PlayerColor color, int position) {
  if (position <= 0) {
    return BoardLayout.baseSlots(color).first;
  }
  if (position <= 52) {
    final idx = BoardPath.globalIndex(color, position);
    return BoardLayout.trackPoints()[idx];
  }
  final points = BoardLayout.homeStretchPoints(color);
  final index = (position - 53).clamp(0, points.length - 1);
  return points[index];
}

/// Renders the board plus every player's pieces on top of it, positioned
/// with [BoardLayout]'s fractional geometry so it scales to any board size.
class BoardWidget extends StatelessWidget {
  final List<LudoPlayer> players;

  /// Pieces eligible to be tapped this turn, encoded as `color.index*10+id`.
  final Set<int> movablePieceKeys;
  final void Function(Piece piece)? onPieceTap;

  /// The current player's color -- highlighted on the board in place of a
  /// separate "whose turn" banner.
  final PlayerColor? activeColor;

  /// Colors that have already finished all 4 pieces, mapped to their
  /// 1-based placement (1 = 1st). A finished color's yard shows its rank
  /// card instead of empty base slots for the rest of the match.
  final Map<PlayerColor, int> finishedRanks;

  /// While a piece is stepping across the board (moving forward, or
  /// retreating back to base after being captured), its position is driven
  /// by its entry here instead of its real (already-updated) engine
  /// position, so the UI can show it walking cell-by-cell along the actual
  /// track rather than jumping/sliding straight to where it landed. Keyed
  /// by piece so more than one can be mid-walk at once (e.g. the mover and
  /// a captured piece retreating at the same time).
  final Map<Piece, Offset> walkingFractions;

  /// Pieces currently in [walkingFractions] whose steps arrive faster than
  /// a normal walk (currently: the fast capture-retreat) -- these get a
  /// short position tween so each waypoint is actually reached before the
  /// next one arrives, instead of a longer tween lagging behind. Pieces
  /// walking forward at the normal pace are *not* in this set, and get a
  /// tween that matches their own slower step cadence so the motion stays
  /// continuous instead of hopping then pausing between steps.
  final Set<Piece> fastWalkPieces;

  /// Builds the dice widget for the given pixel size. Anchored on the
  /// board itself at [activeColor]'s own star/safe cell, and slides there
  /// as [activeColor] changes turn to turn.
  final Widget Function(double size)? diceBuilder;

  const BoardWidget({
    super.key,
    required this.players,
    this.movablePieceKeys = const {},
    this.onPieceTap,
    this.activeColor,
    this.finishedRanks = const {},
    this.walkingFractions = const {},
    this.fastWalkPieces = const {},
    this.diceBuilder,
  });

  static int pieceKey(PlayerColor color, int id) => color.index * 10 + id;

  Offset _fractionFor(Piece piece) {
    final walking = walkingFractions[piece];
    if (walking != null) {
      return walking;
    }
    if (piece.isInBase) {
      return BoardLayout.baseSlots(piece.color)[piece.id];
    }
    if (piece.isFinished) {
      return BoardLayout.finishedSlots(piece.color)[piece.id];
    }
    return fractionForPiecePosition(piece.color, piece.position);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final pieceSize = BoardLayout.scaleLength(0.105, side);

        // Group pieces that land on the same cell so stacked pieces nudge
        // apart instead of fully overlapping and hiding each other.
        final stacks = <String, List<Piece>>{};
        final fractionByPiece = <Piece, Offset>{};
        for (final player in players) {
          for (final piece in player.pieces) {
            final frac = _fractionFor(piece);
            fractionByPiece[piece] = frac;
            // Finished pieces each get their own dedicated home slot, so
            // they never need stack-nudging against one another.
            if (piece.isFinished) continue;
            final key = '${frac.dx.toStringAsFixed(3)}_${frac.dy.toStringAsFixed(3)}';
            stacks.putIfAbsent(key, () => []).add(piece);
          }
        }

        final pieceWidgets = <Widget>[];
        for (final player in players) {
          for (final piece in player.pieces) {
            final frac = fractionByPiece[piece]!;

            // A single piece is already drawn larger than one board cell
            // (for visibility/tap-target size), which is fine alone -- but
            // N pieces sharing a cell each shrink to 1/N of that size (2
            // pieces -> 50% each, 3 -> 33%, ...), staying fully visible
            // side by side instead of any of them hiding behind another,
            // packed into a small grid centered on the cell.
            // Sized to actually fit 4 of them, non-overlapping and clear
            // of neighboring colors, inside the hub's own wedge (see
            // BoardLayout.finishedSlots) -- 0.6x and 0.45x were both too
            // big for that space once all 4 of a color's pieces finish;
            // 0.28x is close to the largest that still fits with margin.
            var effectiveSize = piece.isFinished ? pieceSize * 0.28 : pieceSize;

            Offset nudge = Offset.zero;
            if (!piece.isFinished) {
              final key = '${frac.dx.toStringAsFixed(3)}_${frac.dy.toStringAsFixed(3)}';
              final stack = stacks[key]!;
              final stackIndex = stack.indexOf(piece);
              final n = stack.length;
              if (n > 1) {
                effectiveSize = pieceSize / n;
                final cols = n <= 3 ? n : (n == 4 ? 2 : 3);
                final rows = (n / cols).ceil();
                final row = stackIndex ~/ cols;
                final col = stackIndex % cols;
                final itemsInRow = (row == rows - 1) ? (n - row * cols) : cols;
                final rowWidth = itemsInRow * effectiveSize;
                final gridHeight = rows * effectiveSize;
                nudge = Offset(
                  -rowWidth / 2 + (col + 0.5) * effectiveSize,
                  -gridHeight / 2 + (row + 0.5) * effectiveSize,
                );
              }
            }

            final center = BoardLayout.toCanvas(frac, side) + nudge;
            final movable = movablePieceKeys.contains(pieceKey(piece.color, piece.id));
            // While a piece is being manually walked cell-by-cell, its
            // tween needs to roughly match how fast new waypoints arrive --
            // too slow and it lags behind, visually cutting straight to
            // wherever the walk ends instead of tracing the path; too fast
            // (relative to the step delay) and it hops to each waypoint
            // then visibly pauses before the next one. Fast retreat steps
            // get a short tween; normal forward steps get one close to
            // their own slower cadence; a non-walking position change
            // (e.g. snapping to the real engine position once a walk
            // finishes) gets the slowest, smoothest transition.
            final isFastWalking = fastWalkPieces.contains(piece);
            final isWalking = walkingFractions.containsKey(piece);
            final tweenMs = isFastWalking ? 45 : (isWalking ? 380 : 340);

            pieceWidgets.add(AnimatedPositioned(
              key: ValueKey('${piece.color.name}_${piece.id}'),
              duration: Duration(milliseconds: tweenMs),
              curve: Curves.easeInOut,
              left: center.dx - effectiveSize / 2,
              top: center.dy - effectiveSize / 2,
              child: PieceAvatar(
                color: piece.color,
                size: effectiveSize,
                photoPath: player.photoPath,
                initial: player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                isBot: player.isBot,
                highlighted: movable,
                onTap: movable && onPieceTap != null ? () => onPieceTap!(piece) : null,
              ),
            ));
          }
        }

        final finishCardWidgets = <Widget>[];
        for (final entry in finishedRanks.entries) {
          final rect = BoardLayout.yardRect(entry.key);
          final topLeft = BoardLayout.toCanvas(Offset(rect[0], rect[1]), side);
          final bottomRight = BoardLayout.toCanvas(Offset(rect[0] + rect[2], rect[1] + rect[3]), side);
          finishCardWidgets.add(Positioned(
            key: ValueKey('finish_card_${entry.key.name}'),
            left: topLeft.dx,
            top: topLeft.dy,
            width: bottomRight.dx - topLeft.dx,
            height: bottomRight.dy - topLeft.dy,
            child: Padding(
              padding: EdgeInsets.all(side * 0.01),
              child: FinishCrownBadge(rank: entry.value),
            ),
          ));
        }

        Widget? diceOverlay;
        if (diceBuilder != null && activeColor != null) {
          final anchorFrac = BoardLayout.diceAnchor(activeColor!);
          final overlaySize = side * 0.12;
          // The tappable box is deliberately bigger than the dice's own
          // visual size -- the dice looked hard to tap reliably (needed
          // several attempts), especially while it's still mid-slide
          // between player anchors. Padding the hit area well past the
          // visible edges makes near-misses register without changing
          // how big the dice actually looks.
          final tapSize = overlaySize * 1.7;
          final c = BoardLayout.toCanvas(anchorFrac, side);
          diceOverlay = AnimatedPositioned(
            key: const ValueKey('dice_overlay'),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeInOut,
            left: c.dx - tapSize / 2,
            top: c.dy - tapSize / 2,
            width: tapSize,
            height: tapSize,
            child: diceBuilder!(overlaySize),
          );
        }

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            // The confirmed dice position deliberately pokes slightly
            // outside the board's own edge -- Stack clips overflowing
            // children by default, which was cutting it off.
            clipBehavior: Clip.none,
            children: [
              CustomPaint(size: Size(side, side), painter: BoardPainter(activeColor: activeColor)),
              ...pieceWidgets,
              ...finishCardWidgets,
              if (diceOverlay != null) diceOverlay,
            ],
          ),
        );
      },
    );
  }
}
