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

    final exitingBase = options.where((p) => p.isInBase).toList();
    if (exitingBase.isNotEmpty) return exitingBase.first;

    return _mostAdvanced(options);
  }

  static Piece _chooseHard(LudoEngine engine, List<Piece> options, int diceValue) {
    final finishing = options.where((p) => !p.isInBase && p.position + diceValue == 57).toList();
    if (finishing.isNotEmpty) return finishing.first;

    final capture = _findCapturingMove(engine, options, diceValue);
    if (capture != null) return capture;

    final safeMoves = options.where((p) {
      final newPos = p.isInBase ? 1 : p.position + diceValue;
      if (newPos < 1 || newPos > 52) return true; // home stretch/finish counts as safe
      final idx = BoardPath.globalIndex(p.color, newPos);
      return BoardPath.isSafeGlobalIndex(idx);
    }).toList();
    if (safeMoves.isNotEmpty) return _mostAdvanced(safeMoves);

    final exitingBase = options.where((p) => p.isInBase).toList();
    if (exitingBase.isNotEmpty) return exitingBase.first;

    return _mostAdvanced(options);
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
