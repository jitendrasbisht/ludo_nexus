import 'dart:math';

import '../models/bot_difficulty.dart';
import '../models/piece.dart';
import 'board_path.dart';
import 'ludo_engine.dart';

/// Decides which piece a bot should move, given the dice roll and the
/// current board state.
///
/// Note this only ever chooses *which piece* to move -- it never touches
/// the dice roll itself. The dice (see DiceRoller) is always fair and
/// identical for bots and humans; difficulty only changes how cleverly
/// the bot uses the roll it was given. This keeps the "the dice feel
/// rigged" complaint (the #1 player trust issue in this genre) off the
/// table entirely.
class AiBot {
  static final Random _random = Random();

  static Piece choosePiece(
    LudoEngine engine,
    List<Piece> options,
    BotDifficulty difficulty,
    int diceValue,
  ) {
    if (options.isEmpty) {
      throw ArgumentError('choosePiece called with no movable pieces');
    }
    if (options.length == 1) return options.first;

    switch (difficulty) {
      case BotDifficulty.easy:
        return options[_random.nextInt(options.length)];
      case BotDifficulty.medium:
        return _chooseMedium(engine, options, diceValue);
      case BotDifficulty.hard:
        return _chooseHard(engine, options, diceValue);
    }
  }

  static Piece _chooseMedium(LudoEngine engine, List<Piece> options, int diceValue) {
    final capture = _findCapturingMove(engine, options, diceValue);
    if (capture != null) return capture;

    final threatened = _mostThreatenedPiece(engine, options);
    if (threatened != null) return threatened;

    final exitingBase = options.where((p) => p.isInBase).toList();
    if (exitingBase.isNotEmpty) return exitingBase.first;

    final safeMoves = _safeMoves(options, diceValue);
    if (safeMoves.isNotEmpty) return _mostAdvanced(safeMoves);

    return _mostAdvanced(options);
  }

  static Piece _chooseHard(LudoEngine engine, List<Piece> options, int diceValue) {
    final finishing = options.where((p) => !p.isInBase && p.position + diceValue == 57).toList();
    if (finishing.isNotEmpty) return finishing.first;

    final capture = _findCapturingMove(engine, options, diceValue);
    if (capture != null) return capture;

    final threatened = _mostThreatenedPiece(engine, options);
    if (threatened != null) return threatened;

    final exitingBase = options.where((p) => p.isInBase).toList();
    if (exitingBase.isNotEmpty) return exitingBase.first;

    final safeMoves = _safeMoves(options, diceValue);
    if (safeMoves.isNotEmpty) return _mostAdvanced(safeMoves);

    return _mostAdvanced(options);
  }

  static List<Piece> _safeMoves(List<Piece> options, int diceValue) {
    return options.where((p) {
      final newPos = p.isInBase ? 1 : p.position + diceValue;
      if (newPos < 1 || newPos > 52) return true; // home stretch/finish counts as safe
      final idx = BoardPath.globalIndex(p.color, newPos);
      return BoardPath.isSafeGlobalIndex(idx);
    }).toList();
  }

  /// Looks at the bot's own pieces (among [options]) that are *currently*
  /// sitting somewhere an opponent could capture them next turn (1-6 steps
  /// behind, on a non-safe cell) -- without this, the bot only ever reacts
  /// to captures it can make itself, never to ones about to happen to it,
  /// which read as it ignoring the board. Returns the piece under the most
  /// immediate threat (fewest steps away for the nearest hunter), or null
  /// if nothing in [options] is currently threatened.
  static Piece? _mostThreatenedPiece(LudoEngine engine, List<Piece> options) {
    Piece? best;
    var bestDistance = 7;
    for (final piece in options) {
      if (!piece.isOnSharedTrack) continue;
      final idx = BoardPath.globalIndex(piece.color, piece.position);
      if (BoardPath.isSafeGlobalIndex(idx)) continue;

      for (final other in engine.players) {
        if (other.color == piece.color) continue;
        for (final otherPiece in other.pieces) {
          if (!otherPiece.isOnSharedTrack) continue;
          final otherIdx = BoardPath.globalIndex(otherPiece.color, otherPiece.position);
          final distance = (idx - otherIdx) % BoardPath.trackLength;
          if (distance >= 1 && distance <= 6 && distance < bestDistance) {
            bestDistance = distance;
            best = piece;
          }
        }
      }
    }
    return best;
  }

  static Piece? _findCapturingMove(LudoEngine engine, List<Piece> options, int diceValue) {
    for (final piece in options) {
      final newPos = piece.isInBase ? 1 : piece.position + diceValue;
      if (newPos < 1 || newPos > 52) continue;
      final idx = BoardPath.globalIndex(piece.color, newPos);
      if (BoardPath.isSafeGlobalIndex(idx)) continue;

      for (final other in engine.players) {
        if (other.color == piece.color) continue;
        for (final otherPiece in other.pieces) {
          if (!otherPiece.isOnSharedTrack) continue;
          final otherIdx = BoardPath.globalIndex(otherPiece.color, otherPiece.position);
          if (otherIdx == idx) return piece;
        }
      }
    }
    return null;
  }

  static Piece _mostAdvanced(List<Piece> options) {
    final sorted = [...options]..sort((a, b) => b.position.compareTo(a.position));
    return sorted.first;
  }
}
