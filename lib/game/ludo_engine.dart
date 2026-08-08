import '../models/piece.dart';
import '../models/player.dart';
import 'board_path.dart';
import 'dice_roller.dart';

class MoveResult {
  final bool success;
  final Piece? piece;
  final List<Piece> capturedPieces;
  final bool finishedPiece;
  final bool wonGame;

  const MoveResult({
    required this.success,
    this.piece,
    this.capturedPieces = const [],
    this.finishedPiece = false,
    this.wonGame = false,
  });
}

/// Core rules engine for a local (pass-and-play + bots) Ludo match.
///
/// This class has no Flutter dependency at all -- it is plain Dart so it
/// can be reasoned about and unit-tested independently of the UI layer.
class LudoEngine {
  final List<LudoPlayer> players;
  final DiceRoller dice = DiceRoller();

  int currentPlayerIndex = 0;
  int consecutiveSixes = 0;
  int? lastRoll;
  bool gameOver = false;
  LudoPlayer? winner;

  LudoEngine({required this.players}) {
    if (players.length < 2 || players.length > 4) {
      throw ArgumentError('Ludo requires 2 to 4 players');
    }
  }

  LudoPlayer get currentPlayer => players[currentPlayerIndex];

  /// True once three 6s have been rolled back to back by the same player --
  /// the standard rule that forfeits the turn to prevent one player from
  /// hogging the board forever on a lucky streak.
  bool get mustForfeitTurn => consecutiveSixes >= 3;

  /// Which of the current player's pieces can legally move given the
  /// dice value that was just rolled. Empty means the turn must be skipped.
  List<Piece> movablePieces(int diceValue) {
    final result = <Piece>[];
    for (final piece in currentPlayer.pieces) {
      if (piece.isFinished) continue;
      if (piece.isInBase) {
        if (diceValue == 6) result.add(piece);
      } else {
        final newPos = piece.position + diceValue;
        if (newPos <= 57) result.add(piece);
      }
    }
    return result;
  }

  int rollDice() {
    if (gameOver) {
      throw StateError('Cannot roll, the game is already over');
    }
    final value = dice.roll();
    lastRoll = value;
    consecutiveSixes = (value == 6) ? consecutiveSixes + 1 : 0;
    return value;
  }

  /// Moves [piece] by [diceValue] steps, applying capture and win rules,
  /// and advances the turn unless the roll was a 6 (which grants another
  /// roll for the same player).
  MoveResult movePiece(Piece piece, int diceValue) {
    if (gameOver) return const MoveResult(success: false);
    if (!currentPlayer.pieces.contains(piece)) {
      return const MoveResult(success: false);
    }

    if (piece.isInBase) {
      if (diceValue != 6) return const MoveResult(success: false);
      piece.position = 1;
    } else {
      final newPos = piece.position + diceValue;
      if (newPos > 57) return const MoveResult(success: false);
      piece.position = newPos;
    }

    final captured = <Piece>[];
    final finished = piece.position == 57;

    if (piece.isOnSharedTrack) {
      final globalIdx = BoardPath.globalIndex(piece.color, piece.position);
      if (!BoardPath.isSafeGlobalIndex(globalIdx)) {
        for (final other in players) {
          if (other.color == piece.color) continue;
          for (final otherPiece in other.pieces) {
            if (!otherPiece.isOnSharedTrack) continue;
            final otherIdx = BoardPath.globalIndex(otherPiece.color, otherPiece.position);
            if (otherIdx == globalIdx) {
              otherPiece.position = 0;
              captured.add(otherPiece);
            }
          }
        }
      }
    }

    var won = false;
    if (currentPlayer.hasWon) {
      gameOver = true;
      winner = currentPlayer;
      won = true;
    }

    if (!gameOver) {
      final rolledSix = diceValue == 6;
      _advanceTurn(forceAdvance: !rolledSix);
    }

    return MoveResult(
      success: true,
      piece: piece,
      capturedPieces: captured,
      finishedPiece: finished,
      wonGame: won,
    );
  }

  /// Called by the UI when the current roll leaves no legal move
  /// (or after a forfeited third consecutive 6).
  void skipTurn() {
    _advanceTurn(forceAdvance: true);
  }

  void _advanceTurn({required bool forceAdvance}) {
    if (!forceAdvance) return;
    consecutiveSixes = 0;
    var tries = 0;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      tries++;
    } while (players[currentPlayerIndex].hasWon && tries < players.length);
  }
}
