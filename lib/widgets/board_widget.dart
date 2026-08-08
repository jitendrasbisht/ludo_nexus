import 'package:flutter/material.dart';

import '../game/board_layout.dart';
import '../game/board_path.dart';
import '../models/piece.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import 'board_painter.dart';
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

  /// While a piece is stepping across the board, its position is driven by
  /// [walkingFraction] instead of its real (already-updated) engine
  /// position, so the UI can show it walking cell-by-cell rather than
  /// jumping straight to where it landed.
  final Piece? walkingPiece;
  final Offset? walkingFraction;

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
    this.walkingPiece,
    this.walkingFraction,
    this.diceBuilder,
  });

  static int pieceKey(PlayerColor color, int id) => color.index * 10 + id;

  Offset _fractionFor(Piece piece) {
    if (piece == walkingPiece && walkingFraction != null) {
      return walkingFraction!;
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
            final effectiveSize = piece.isFinished ? pieceSize * 0.6 : pieceSize;

            Offset nudge = Offset.zero;
            if (!piece.isFinished) {
              final key = '${frac.dx.toStringAsFixed(3)}_${frac.dy.toStringAsFixed(3)}';
              final stack = stacks[key]!;
              final stackIndex = stack.indexOf(piece);
              nudge = stack.length > 1
                  ? Offset(
                      (stackIndex % 2 == 0 ? -1 : 1) * pieceSize * 0.22,
                      (stackIndex ~/ 2 == 0 ? -1 : 1) * pieceSize * 0.22,
                    )
                  : Offset.zero;
            }

            final center = BoardLayout.toCanvas(frac, side) + nudge;
            final movable = movablePieceKeys.contains(pieceKey(piece.color, piece.id));

            pieceWidgets.add(AnimatedPositioned(
              key: ValueKey('${piece.color.name}_${piece.id}'),
              duration: const Duration(milliseconds: 340),
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

        Widget? diceOverlay;
        if (diceBuilder != null && activeColor != null) {
          final anchorFrac = BoardLayout.diceAnchor(activeColor!);
          final overlaySize = side * 0.12;
          final c = BoardLayout.toCanvas(anchorFrac, side);
          diceOverlay = AnimatedPositioned(
            key: const ValueKey('dice_overlay'),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            left: c.dx - overlaySize / 2,
            top: c.dy - overlaySize / 2,
            width: overlaySize,
            height: overlaySize,
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
              if (diceOverlay != null) diceOverlay,
            ],
          ),
        );
      },
    );
  }
}
