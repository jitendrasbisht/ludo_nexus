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

  group('home stretch entry', () {
    test('a roll that would cross from the shared track into the home stretch stops at the entry cell', () {
      final red = _player(PlayerColor.red);
      final engine = LudoEngine(players: [red, _player(PlayerColor.green)]);
      engine.currentPlayerIndex = engine.players.indexOf(red);

      final piece = red.pieces.first..position = 50;
      // 50 + 6 = 56 would land deep in the home stretch (and 50 + 6 could
      // even reach past it on a smaller board) -- entering always stops
      // exactly at 53, leftover pips discarded, so finishing needs a
      // separate later move.
      final result = engine.movePiece(piece, 6);

      expect(result.success, isTrue);
      expect(piece.position, 53);
      expect(result.finishedPiece, isFalse);
    });

    test('a piece already in the home stretch keeps the normal exact-landing rule', () {
      final red = _player(PlayerColor.red);
      final engine = LudoEngine(players: [red, _player(PlayerColor.green)]);
      engine.currentPlayerIndex = engine.players.indexOf(red);

      final piece = red.pieces.first..position = 53;
      // 53 + 6 = 59, overshoots 57 -- not a legal move for this piece
      // (the other 3 pieces are still in base and stay movable on a 6).
      expect(engine.movablePieces(6), isNot(contains(piece)));

      final result = engine.movePiece(piece, 4); // 53 + 4 = 57, exact
      expect(result.success, isTrue);
      expect(result.finishedPiece, isTrue);
    });

    test('landing exactly on 52 from the shared track is not treated as crossing', () {
      final red = _player(PlayerColor.red);
      final engine = LudoEngine(players: [red, _player(PlayerColor.green)]);
      engine.currentPlayerIndex = engine.players.indexOf(red);

      final piece = red.pieces.first..position = 48;
      final result = engine.movePiece(piece, 4); // 48 + 4 = 52, still shared track

      expect(result.success, isTrue);
      expect(piece.position, 52);
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

    test('a third consecutive 6 forfeits before any move, and skipTurn resets the streak', () {
      final engine = LudoEngine(players: [_player(PlayerColor.red), _player(PlayerColor.green)]);
      final mover = engine.currentPlayerIndex;

      engine.lastRoll = 6;
      engine.consecutiveBonusRolls = 2;
      expect(engine.mustForfeitTurn, isTrue);

      engine.skipTurn();

      expect(engine.consecutiveBonusRolls, 0);
      expect(engine.mustForfeitTurn, isFalse);
      expect(engine.currentPlayerIndex, isNot(mover));
    });

    test('capturing a piece grants the same player another turn', () {
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final engine = LudoEngine(players: [red, green]);

      red.pieces.first.position = 11; // global index 10, not safe
      final greenPiece = green.pieces.first..position = 45;
      engine.currentPlayerIndex = engine.players.indexOf(green);

      final result = engine.movePiece(greenPiece, 5); // lands on global index 10, captures red

      expect(result.capturedPieces, isNotEmpty);
      expect(engine.currentPlayerIndex, engine.players.indexOf(green));
      expect(engine.consecutiveBonusRolls, 1);
    });

    test('finishing a piece grants the same player another turn', () {
      final red = _player(PlayerColor.red);
      final engine = LudoEngine(players: [red, _player(PlayerColor.green)]);

      final piece = red.pieces.first..position = 56;
      engine.currentPlayerIndex = engine.players.indexOf(red);

      final result = engine.movePiece(piece, 1);

      expect(result.finishedPiece, isTrue);
      expect(engine.currentPlayerIndex, engine.players.indexOf(red));
      expect(engine.consecutiveBonusRolls, 1);
    });

    test('a capture/finish does not stack with a 6 -- still only one bonus roll', () {
      final red = _player(PlayerColor.red);
      final engine = LudoEngine(players: [red, _player(PlayerColor.green)]);

      final piece = red.pieces.first..position = 51;
      engine.currentPlayerIndex = engine.players.indexOf(red);

      // Rolling a 6 alone is enough to earn the bonus -- this particular
      // move also crosses into the home stretch (clamped to 53, not 57;
      // see "entering the home stretch always costs its own turn" below),
      // so it isn't a finish, but the 6 still grants exactly one bonus.
      engine.movePiece(piece, 6);

      expect(engine.consecutiveBonusRolls, 1);
    });

    test('three consecutive bonus rolls (mix of 6s/captures/finishes) forfeits the third', () {
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final engine = LudoEngine(players: [red, green]);
      engine.currentPlayerIndex = engine.players.indexOf(red);

      // Bonus roll 1: a plain 6, no capture/finish.
      final firstPiece = red.pieces[0];
      engine.movePiece(firstPiece, 6);
      expect(engine.consecutiveBonusRolls, 1);
      expect(engine.currentPlayerIndex, engine.players.indexOf(red));

      // Bonus roll 2: a capture, not a 6.
      green.pieces.first.position = 8; // global index 20, not safe
      final secondPiece = red.pieces[1]..position = 16;
      engine.movePiece(secondPiece, 5); // lands on global index 20, captures green
      expect(engine.consecutiveBonusRolls, 2);
      expect(engine.currentPlayerIndex, engine.players.indexOf(red));

      // Bonus roll 3 would-be: another capture. The move still applies, but
      // no further roll is granted -- turn passes to the next player.
      green.pieces[1].position = 18; // global index 30, not safe
      final thirdPiece = red.pieces[2]..position = 26;
      final result = engine.movePiece(thirdPiece, 5); // lands on global index 30, captures green

      expect(result.capturedPieces, isNotEmpty);
      expect(engine.consecutiveBonusRolls, 0);
      expect(engine.currentPlayerIndex, isNot(engine.players.indexOf(red)));
    });
  });

  group('win detection', () {
    test('finishing the last piece wins the game', () {
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final engine = LudoEngine(players: [red, green]);

      for (final piece in red.pieces.take(3)) {
        piece.position = 57;
      }
      final lastPiece = red.pieces.last..position = 56;
      engine.currentPlayerIndex = engine.players.indexOf(red);

      final result = engine.movePiece(lastPiece, 1);

      expect(result.success, isTrue);
      expect(result.wonGame, isTrue);
      expect(result.finishedPiece, isTrue);
      expect(result.justFinishedPlayer, red);
      expect(result.justFinishedRank, 1);
      expect(engine.gameOver, isTrue);
      expect(engine.winner, red);
      // With only 2 players, the survivor is automatically last place --
      // the match can't continue with nobody left to play against them.
      expect(engine.finishOrder, [red, green]);
    });

    test('with 3+ players, the match continues after the first finish', () {
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final yellow = _player(PlayerColor.yellow);
      final engine = LudoEngine(players: [red, green, yellow]);

      for (final piece in red.pieces.take(3)) {
        piece.position = 57;
      }
      final lastPiece = red.pieces.last..position = 56;
      engine.currentPlayerIndex = engine.players.indexOf(red);

      final result = engine.movePiece(lastPiece, 1);

      expect(result.justFinishedPlayer, red);
      expect(result.justFinishedRank, 1);
      expect(result.wonGame, isFalse);
      expect(engine.gameOver, isFalse);
      expect(engine.finishOrder, [red]);
      // Green and yellow are still playing -- the turn should move on to
      // one of them, never back to the finished red.
      expect(engine.currentPlayer, isNot(red));
    });

    test('the last remaining player is auto-ranked last once everyone else has finished', () {
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final yellow = _player(PlayerColor.yellow);
      final blue = _player(PlayerColor.blue);
      final engine = LudoEngine(players: [red, green, yellow, blue]);

      // red, green, yellow already finished; only blue is still playing.
      for (final p in [red, green, yellow]) {
        for (final piece in p.pieces) {
          piece.position = 57;
        }
        engine.finishOrder.add(p);
      }
      engine.winner = red;

      for (final piece in blue.pieces.take(3)) {
        piece.position = 57;
      }
      final lastBluePiece = blue.pieces.last..position = 56;
      engine.currentPlayerIndex = engine.players.indexOf(blue);

      final result = engine.movePiece(lastBluePiece, 1);

      expect(result.wonGame, isTrue);
      expect(result.justFinishedPlayer, blue);
      expect(result.justFinishedRank, 4);
      expect(engine.finishOrder, [red, green, yellow, blue]);
      expect(engine.gameOver, isTrue);
    });

    test('the 3rd finisher ends the match immediately -- the 4th player never needs to finish', () {
      final red = _player(PlayerColor.red);
      final green = _player(PlayerColor.green);
      final yellow = _player(PlayerColor.yellow);
      final blue = _player(PlayerColor.blue);
      final engine = LudoEngine(players: [red, green, yellow, blue]);

      // red and green already finished; blue never gets a piece off base.
      for (final p in [red, green]) {
        for (final piece in p.pieces) {
          piece.position = 57;
        }
        engine.finishOrder.add(p);
      }
      engine.winner = red;

      for (final piece in yellow.pieces.take(3)) {
        piece.position = 57;
      }
      final lastYellowPiece = yellow.pieces.last..position = 56;
      engine.currentPlayerIndex = engine.players.indexOf(yellow);

      final result = engine.movePiece(lastYellowPiece, 1);

      expect(result.wonGame, isTrue);
      expect(result.justFinishedPlayer, yellow);
      expect(result.justFinishedRank, 3);
      // Blue is auto-appended as last place without ever finishing a piece.
      expect(engine.finishOrder, [red, green, yellow, blue]);
      expect(blue.hasWon, isFalse);
      expect(engine.gameOver, isTrue);
    });
  });
}
