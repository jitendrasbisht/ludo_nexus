import '../models/piece.dart';
import '../models/player.dart';
import 'board_path.dart';
import 'dice_roller.dart';

class MoveResult {
  final bool success;
  final Piece? piece;
  final List<Piece> capturedPieces;
  final bool finishedPiece;

  /// Set when this move was the one that completed all 4 of a player's
  /// pieces -- the game doesn't necessarily end here (see [wonGame]), play
  /// continues for whoever's left, but the UI should still call this out.
  final LudoPlayer? justFinishedPlayer;

  /// 1-based placement ([justFinishedPlayer]'s rank) when they finished.
  final int? justFinishedRank;

  /// True once this move brought the number of still-playing (unfinished)
  /// players down to 1 -- the point the whole match ends, since there's no
  /// one left to compete against the last player for the remaining spots.
  final bool wonGame;

  const MoveResult({
    required this.success,
    this.piece,
    this.capturedPieces = const [],
    this.finishedPiece = false,
    this.justFinishedPlayer,
    this.justFinishedRank,
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
  int consecutiveBonusRolls = 0;
  int? lastRoll;
  bool gameOver = false;

  /// Players in the order they finished all 4 pieces -- index 0 is 1st
  /// place. The match keeps going after the first finish; once only one
  /// player is still playing they're appended here automatically (last
  /// place by default, since there's no one left to compete against).
  final List<LudoPlayer> finishOrder = [];

  /// The first player to finish (1st place) -- kept for the simple "who
  /// won" case; see [finishOrder] for the full standings.
  LudoPlayer? winner;

  LudoEngine({required this.players}) {
    if (players.length < 2 || players.length > 4) {
      throw ArgumentError('Ludo requires 2 to 4 players');
    }
  }

  LudoPlayer get currentPlayer => players[currentPlayerIndex];

  /// True once a just-rolled 6 would be the third consecutive bonus roll
  /// (a run of 6s / captures / finishes) for the same player -- the
  /// standard "three 6s in a row forfeits the turn" rule, generalized to
  /// the other bonus-roll triggers added alongside it.
  ///
  /// This can only ever fire for a 6: whether a non-6 roll earns a bonus
  /// depends on whether the move that roll allows ends up capturing or
  /// finishing a piece, which isn't known until [movePiece] actually
  /// applies it. So a would-be third bonus roll from a capture or finish
  /// is instead settled inside [movePiece] itself, after the move happens
  /// (the move still counts, but no further roll is granted).
  bool get mustForfeitTurn => lastRoll == 6 && consecutiveBonusRolls >= 2;

  /// Which of the current player's pieces can legally move given the
  /// dice value that was just rolled. Empty means the turn must be skipped.
  List<Piece> movablePieces(int diceValue) {
    final result = <Piece>[];
    for (final piece in currentPlayer.pieces) {
      if (piece.isFinished) continue;
      if (piece.isInBase) {
        if (diceValue == 6) result.add(piece);
      } else if (targetPosition(piece, diceValue) <= 57) {
        result.add(piece);
      }
    }
    return result;
  }

  /// Where [piece] would land after moving [diceValue] steps, without
  /// mutating anything -- used by [movePiece] itself and by the UI so its
  /// step-by-step walk animation ends up exactly where the engine will
  /// actually place the piece.
  ///
  /// Crossing from the shared track into the private home stretch always
  /// stops the piece exactly at the entry cell (53), even if the roll had
  /// pips left over -- so a piece can never cover the shared track and the
  /// home stretch in the same move, and finishing (57) always needs a
  /// separate roll after entering. Once a piece is already inside the home
  /// stretch, it keeps the normal exact-landing rule (a roll that would
  /// overshoot 57 is simply illegal).
  int targetPosition(Piece piece, int diceValue) {
    if (piece.isInBase) return 1;
    final newPos = piece.position + diceValue;
    if (piece.isOnSharedTrack && newPos > 52) return 53;
    return newPos;
  }

  int rollDice() {
    if (gameOver) {
      throw StateError('Cannot roll, the game is already over');
    }
    final value = dice.roll();
    lastRoll = value;
    return value;
  }

  /// Moves [piece] by [diceValue] steps, applying capture and win rules.
  ///
  /// The turn passes to the next player unless this roll earned a bonus --
  /// rolling a 6, capturing an opponent's piece, or getting a piece all
  /// the way home each grant one extra roll for the same player (never
  /// more than one, even if several of those happen on the same move).
  /// Three consecutive bonus rolls (any mix of the three) forfeits the
  /// would-be third extra roll, same anti-hogging cap as before.
  MoveResult movePiece(Piece piece, int diceValue) {
    if (gameOver) return const MoveResult(success: false);
    if (!currentPlayer.pieces.contains(piece)) {
      return const MoveResult(success: false);
    }

    if (piece.isInBase) {
      if (diceValue != 6) return const MoveResult(success: false);
      piece.position = 1;
    } else {
      final target = targetPosition(piece, diceValue);
      if (target > 57) return const MoveResult(success: false);
      piece.position = target;
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

    LudoPlayer? justFinishedPlayer;
    int? justFinishedRank;
    if (currentPlayer.hasWon && !finishOrder.contains(currentPlayer)) {
      finishOrder.add(currentPlayer);
      justFinishedPlayer = currentPlayer;
      justFinishedRank = finishOrder.length;
      winner ??= currentPlayer;
    }

    // The match ends once only one player is still playing -- they're
    // automatically last place, since there's nobody left to finish
    // against them.
    final stillPlaying = players.where((p) => !finishOrder.contains(p)).toList();
    var won = false;
    if (stillPlaying.length <= 1) {
      finishOrder.addAll(stillPlaying);
      gameOver = true;
      won = true;
    }

    if (!gameOver) {
      // A player who just finished their own last piece has nothing left
      // to move -- there's no roll to grant them even if this move would
      // otherwise have earned one, so the turn always passes on.
      final earnsBonus =
          justFinishedPlayer == null && (diceValue == 6 || captured.isNotEmpty || finished);
      final bonusGranted = earnsBonus && consecutiveBonusRolls < 2;
      consecutiveBonusRolls = bonusGranted ? consecutiveBonusRolls + 1 : 0;
      _advanceTurn(forceAdvance: !bonusGranted);
    }

    return MoveResult(
      success: true,
      piece: piece,
      capturedPieces: captured,
      finishedPiece: finished,
      justFinishedPlayer: justFinishedPlayer,
      justFinishedRank: justFinishedRank,
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
    consecutiveBonusRolls = 0;
    var tries = 0;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      tries++;
    } while (players[currentPlayerIndex].hasWon && tries < players.length);
  }
}
