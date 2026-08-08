import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_app/game/board_path.dart';
import 'package:ludo_app/game/ludo_engine.dart';
import 'package:ludo_app/models/player.dart';
import 'package:ludo_app/models/player_color.dart';

LudoPlayer _player(PlayerColor color) => LudoPlayer(color: color, name: color.label);

void main() {
  group('base exit', () {
    test('a piece in base can only move on a roll of 6', () {
      final engine = LudoEngine(players: [_player(PlayerColor.red), _player(PlayerColor.green)]);
      final piece = engine.currentPlayer.pieces.first;

      expect(engine.movablePieces(3), isEmpty);
      expect(engine.movablePieces(6), contains(piece));

      final blocked = engine.movePiece(piece, 3);
      expect(blocked.success, isFalse);
      expect(piece.isInBase, isTrue);

      final result = engine.movePiece(piece, 6);
      expect(result.success, isTrue);
      expect(piece.position, 1);
    });
  });

  group('captures', () {
    test('landing on an opponent on a non-safe cell captures it', () {
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final engine = LudoEngine(players: [red, green]);

      final redPiece = red.pieces.first..position = 11; // global index 10, not safe
      expect(BoardPath.isSafeGlobalIndex(BoardPath.globalIndex(PlayerColor.red, 11)), isFalse);

      final greenPiece = green.pieces.first..position = 45;
      engine.currentPlayerIndex = engine.players.indexOf(green);

      final result = engine.movePiece(greenPiece, 5); // also lands on global index 10

      expect(result.success, isTrue);
      expect(result.capturedPieces, [redPiece]);
      expect(redPiece.isInBase, isTrue);
    });

    test('capture still works landing exactly on the last shared-track cell (position 52)', () {
      // Regression guard: relative position 52 is still shared track (see
      // Piece.isOnSharedTrack / BoardPath's 1..52 convention), so a capture
      // there must not be silently skipped.
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final engine = LudoEngine(players: [red, green]);

      final redPiece = red.pieces.first..position = 52;
      expect(BoardPath.isSafeGlobalIndex(BoardPath.globalIndex(PlayerColor.red, 52)), isFalse);

      final greenPiece = green.pieces.first..position = 34;
      engine.currentPlayerIndex = engine.players.indexOf(green);

      final result = engine.movePiece(greenPiece, 5); // lands on the same global cell

      expect(result.capturedPieces, [redPiece]);
      expect(redPiece.isInBase, isTrue);
    });

    test('landing on a safe cell never captures', () {
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final engine = LudoEngine(players: [red, green]);

      final greenPiece = green.pieces.first..position = 40; // global index 0, red's safe start cell
      expect(BoardPath.isSafeGlobalIndex(0), isTrue);

      final redPiece = red.pieces.first; // still in base
      engine.currentPlayerIndex = engine.players.indexOf(red);

      final result = engine.movePiece(redPiece, 6); // exits base straight onto global index 0

      expect(result.success, isTrue);
      expect(result.capturedPieces, isEmpty);
      expect(greenPiece.position, 40);
      expect(greenPiece.isInBase, isFalse);
    });
  });

  group('turn flow', () {
    test('rolling a 6 grants the same player another turn', () {
      final engine = LudoEngine(players: [_player(PlayerColor.red), _player(PlayerColor.green)]);
      final mover = engine.currentPlayerIndex;
      final piece = engine.currentPlayer.pieces.first;

      engine.movePiece(piece, 6);

      expect(engine.currentPlayerIndex, mover);
    });

    test('a non-6 roll advances to the next player', () {
      final engine = LudoEngine(players: [_player(PlayerColor.red), _player(PlayerColor.green)]);
      final mover = engine.currentPlayerIndex;
      final piece = engine.currentPlayer.pieces.first..position = 1;

      engine.movePiece(piece, 3);

      expect(engine.currentPlayerIndex, isNot(mover));
    });

    test('three consecutive 6s force a forfeit, and skipTurn resets the streak', () {
      final engine = LudoEngine(players: [_player(PlayerColor.red), _player(PlayerColor.green)]);
      final mover = engine.currentPlayerIndex;

      engine.consecutiveSixes = 3;
      expect(engine.mustForfeitTurn, isTrue);

      engine.skipTurn();

      expect(engine.consecutiveSixes, 0);
      expect(engine.mustForfeitTurn, isFalse);
      expect(engine.currentPlayerIndex, isNot(mover));
    });

    test('consecutiveSixes always mirrors the trailing 6-streak in the real dice history', () {
      // DiceRoller is deliberately unseeded (Random.secure()), so this
      // drives many real rolls and checks the bookkeeping invariant holds
      // for whatever sequence actually comes up, rather than forcing a
      // specific (unmockable) outcome.
      final engine = LudoEngine(players: [_player(PlayerColor.red), _player(PlayerColor.green)]);

      for (var i = 0; i < 300; i++) {
        engine.rollDice();

        var trailingSixes = 0;
        for (final value in engine.dice.history.reversed) {
          if (value != 6) break;
          trailingSixes++;
        }

        expect(engine.consecutiveSixes, trailingSixes);
        expect(engine.mustForfeitTurn, trailingSixes >= 3);
      }
    });
  });

  group('win detection', () {
    test('finishing the last piece wins the game', () {
      final red = _player(PlayerColor.red);
      final engine = LudoEngine(players: [red, _player(PlayerColor.green)]);

      for (final piece in red.pieces.take(3)) {
        piece.position = 57;
      }
      final lastPiece = red.pieces.last..position = 56;
      engine.currentPlayerIndex = engine.players.indexOf(red);

      final result = engine.movePiece(lastPiece, 1);

      expect(result.success, isTrue);
      expect(result.wonGame, isTrue);
      expect(result.finishedPiece, isTrue);
      expect(engine.gameOver, isTrue);
      expect(engine.winner, red);
    });
  });
}
