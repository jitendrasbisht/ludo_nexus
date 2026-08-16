import 'package:flutter/material.dart';

import '../game/ai_bot.dart';
import '../game/ludo_engine.dart';
import '../models/bot_difficulty.dart';
import '../models/piece.dart';
import '../models/player_color.dart';
import '../services/capture_sound.dart';
import '../services/click_sound.dart';
import '../services/dice_roll_sound.dart';
import '../widgets/app_background.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/leave_game_dialog.dart';
import '../widgets/player_chips_row.dart';

class GameScreen extends StatefulWidget {
  final LudoEngine engine;

  const GameScreen({super.key, required this.engine});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late LudoEngine engine;
  List<Piece> _movable = [];
  bool _busy = false;
  String _statusText = '';
  final Map<Piece, Offset> _walkingFractions = {};
  bool _diceSpinning = false;

  /// True while the leave-game confirmation dialog is up. Bot turns check
  /// this between steps and freeze in place rather than continuing to play
  /// out behind the dialog.
  bool _paused = false;

  Future<void> _waitWhilePaused() async {
    while (_paused && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void initState() {
    super.initState();
    engine = widget.engine;
    _statusText = '${engine.currentPlayer.name}, roll to start!';
    ClickSound.preload();
    DiceRollSound.preload();
    CaptureSound.preload();
    _afterTurnAdvance();
  }

  static String _ordinal(int n) {
    switch (n) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${n}th';
    }
  }

  bool get _canHumanRoll =>
      !engine.gameOver &&
      !_busy &&
      !engine.currentPlayer.isBot &&
      _movable.isEmpty;

  /// Spins the dice face through random values briefly before actually
  /// rolling, so the roll is something the player visibly watches happen
  /// rather than a number just appearing. Plays the dice-in-a-bowl rattle
  /// once for the whole spin -- a distinct sound from the single click used
  /// per step when a piece moves, rather than reusing that same click here.
  Future<int> _rollWithAnimation() async {
    setState(() => _diceSpinning = true);
    const spinDuration = Duration(milliseconds: DiceRollSound.durationMs);
    DiceRollSound.play();
    await Future.delayed(spinDuration);
    final value = engine.rollDice();
    if (mounted) setState(() => _diceSpinning = false);
    return value;
  }

  Future<void> _rollForHuman() async {
    if (!_canHumanRoll) return;
    final mover = engine.currentPlayer;
    setState(() => _busy = true);

    final value = await _rollWithAnimation();
    if (!mounted) return;

    if (engine.mustForfeitTurn) {
      setState(
        () => _statusText =
            "${mover.name}'s bonus streak hit three -- turn forfeited!",
      );
      await Future.delayed(const Duration(milliseconds: 100));
      engine.skipTurn();
      setState(() => _busy = false);
      _afterTurnAdvance();
      return;
    }

    final movable = engine.movablePieces(value);
    if (movable.isEmpty) {
      setState(
        () => _statusText = '${mover.name} rolled a $value -- no legal moves.',
      );
      await Future.delayed(const Duration(milliseconds: 100));
      engine.skipTurn();
      setState(() => _busy = false);
      _afterTurnAdvance();
      return;
    }

    if (movable.length == 1) {
      setState(() => _statusText = '${mover.name} rolled a $value.');
      // A clear gap before the move's click sounds start, so they don't
      // read as a continuation of the dice-roll sound that just finished.
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      await _applyMove(movable.first, value, mover.name);
      return;
    }

    setState(() {
      _movable = movable;
      _statusText = '${mover.name} rolled a $value -- choose a piece to move.';
      _busy = false;
    });
  }

  void _onPieceTap(Piece piece) {
    if (_movable.isEmpty || engine.lastRoll == null) return;
    if (!_movable.contains(piece)) return;
    final mover = engine.currentPlayer;
    final value = engine.lastRoll!;
    setState(() => _movable = []);
    _applyMove(piece, value, mover.name);
  }

  /// Walks [piece] across its intermediate cells one at a time (with a
  /// placeholder click per step -- swap ClickSound for real audio assets
  /// later) instead of jumping straight to where it lands. The engine
  /// isn't touched until the walk finishes, so a capture only reveals
  /// itself once the moving piece visually arrives.
  Future<void> _walkPiece(Piece piece, int diceValue) async {
    final startPos = piece.position;

    if (startPos <= 0) {
      // Exiting base: nothing on the board to visually step through, but
      // still count out the roll with clicks.
      for (var i = 0; i < diceValue; i++) {
        ClickSound.play();
        if (i < diceValue - 1) {
          await Future.delayed(const Duration(milliseconds: 70));
        }
      }
      return;
    }

    for (var step = 1; step <= diceValue; step++) {
      final pos = startPos + step;
      if (pos > 57) break;
      if (!mounted) return;
      setState(() {
        _walkingFractions[piece] = fractionForPiecePosition(piece.color, pos);
      });
      ClickSound.play();
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Walks a just-captured [piece] back from [fromPosition] to base (0) one
  /// cell at a time, retracing the track it actually sits on instead of
  /// sliding straight across the board to its base slot. The per-step delay
  /// is budgeted against the distance so even a piece captured deep on the
  /// track still finishes retreating in well under 2 seconds.
  Future<void> _walkPieceBack(Piece piece, int fromPosition) async {
    if (fromPosition <= 0) return;
    const totalBudgetMs = 1400;
    final stepDelayMs = (totalBudgetMs / fromPosition).clamp(12, 140).round();
    for (var pos = fromPosition - 1; pos >= 0; pos--) {
      if (!mounted) return;
      setState(() {
        _walkingFractions[piece] = fractionForPiecePosition(piece.color, pos);
      });
      await Future.delayed(Duration(milliseconds: stepDelayMs));
    }
  }

  Future<void> _applyMove(Piece piece, int diceValue, String moverName) async {
    setState(() {
      _busy = true;
      _movable = [];
    });

    await _walkPiece(piece, diceValue);
    if (!mounted) return;
    final preMovePositions = {
      for (final p in engine.players.expand((pl) => pl.pieces)) p: p.position,
    };
    final result = engine.movePiece(piece, diceValue);
    if (result.capturedPieces.isNotEmpty) {
      CaptureSound.play();
      await Future.wait([
        for (final cp in result.capturedPieces)
          _walkPieceBack(cp, preMovePositions[cp]!),
      ]);
      if (!mounted) return;
    }
    final bonusGranted =
        !result.wonGame && engine.currentPlayer.color == piece.color;
    setState(() {
      _walkingFractions.remove(piece);
      for (final cp in result.capturedPieces) {
        _walkingFractions.remove(cp);
      }
      String message;
      if (result.justFinishedPlayer != null) {
        message = '$moverName finished ${_ordinal(result.justFinishedRank!)}!';
      } else if (result.capturedPieces.isNotEmpty) {
        message =
            '$moverName captured ${result.capturedPieces.length} piece(s)!';
      } else if (result.finishedPiece) {
        message = '$moverName got a piece home!';
      } else {
        message = '$moverName moved.';
      }
      _statusText = bonusGranted ? '$message Go again!' : message;
    });
    // A finish (someone completing all 4 pieces) gets a much longer pause
    // than an ordinary move -- long enough to actually read the "finished
    // Nth!" banner and see their rank card land on the board, rather than
    // it flashing by mid-sequence when bots are playing back to back.
    final pause = result.justFinishedPlayer != null
        ? const Duration(milliseconds: 1800)
        : const Duration(milliseconds: 80);
    await Future.delayed(pause);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.wonGame) {
      // No popup -- the board stays on screen exactly as it is, showing
      // every player's rank card, for as long as the players want to look
      // at it. See the bottom pill in build() for how they leave.
      return;
    }
    _afterTurnAdvance();
  }

  void _afterTurnAdvance() {
    if (!mounted) return;
    setState(() {});
    if (!engine.gameOver && engine.currentPlayer.isBot && !_paused) {
      Future.delayed(const Duration(milliseconds: 100), _playBotTurn);
    }
  }

  Future<void> _playBotTurn() async {
    if (!mounted || engine.gameOver) return;
    if (_paused) return;
    final bot = engine.currentPlayer;
    if (!bot.isBot) return; // stale callback from a replayed game

    setState(() => _busy = true);
    final value = await _rollWithAnimation();
    if (!mounted) return;
    await _waitWhilePaused();
    if (!mounted) return;
    setState(() => _statusText = '${bot.name} rolled a $value.');
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _waitWhilePaused();
    if (!mounted) return;

    if (engine.mustForfeitTurn) {
      setState(
        () => _statusText =
            "${bot.name}'s bonus streak hit three -- turn forfeited!",
      );
      await Future.delayed(const Duration(milliseconds: 150));
      engine.skipTurn();
      setState(() => _busy = false);
      _afterTurnAdvance();
      return;
    }

    final movable = engine.movablePieces(value);
    if (movable.isEmpty) {
      setState(() => _statusText = '${bot.name} has no legal moves.');
      await Future.delayed(const Duration(milliseconds: 150));
      engine.skipTurn();
      setState(() => _busy = false);
      _afterTurnAdvance();
      return;
    }

    final piece = AiBot.choosePiece(
      engine,
      movable,
      bot.botDifficulty ?? BotDifficulty.medium,
      value,
    );
    await _walkPiece(piece, value);
    if (!mounted) return;
    final preMovePositions = {
      for (final p in engine.players.expand((pl) => pl.pieces)) p: p.position,
    };
    final result = engine.movePiece(piece, value);
    if (result.capturedPieces.isNotEmpty) {
      CaptureSound.play();
      await Future.wait([
        for (final cp in result.capturedPieces)
          _walkPieceBack(cp, preMovePositions[cp]!),
      ]);
      if (!mounted) return;
    }
    final bonusGranted =
        !result.wonGame && engine.currentPlayer.color == piece.color;
    setState(() {
      _walkingFractions.remove(piece);
      for (final cp in result.capturedPieces) {
        _walkingFractions.remove(cp);
      }
      String message;
      if (result.justFinishedPlayer != null) {
        message = '${bot.name} finished ${_ordinal(result.justFinishedRank!)}!';
      } else if (result.capturedPieces.isNotEmpty) {
        message = '${bot.name} captured a piece!';
      } else if (result.finishedPiece) {
        message = '${bot.name} got a piece home!';
      } else {
        message = '${bot.name} moved.';
      }
      _statusText = bonusGranted ? '$message Go again!' : message;
    });
    final pause = result.justFinishedPlayer != null
        ? const Duration(milliseconds: 1800)
        : const Duration(milliseconds: 80);
    await Future.delayed(pause);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.wonGame) {
      // No popup -- the board stays on screen exactly as it is, showing
      // every player's rank card, for as long as the players want to look
      // at it. See the bottom pill in build() for how they leave.
      return;
    }
    _afterTurnAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final current = engine.currentPlayer;
    final movableKeys = {
      for (final p in _movable) BoardWidget.pieceKey(p.color, p.id),
    };
    final finishedRanks = <PlayerColor, int>{
      for (var i = 0; i < engine.finishOrder.length; i++)
        engine.finishOrder[i].color: i + 1,
    };
    final gameOver = engine.gameOver;
    final bottomText = gameOver
        ? '🏆 ${engine.finishOrder.first.name} won! Tap to go back to setup'
        : (_statusText.isEmpty ? 'Tap your dice to roll' : _statusText);

    return PopScope(
      canPop: gameOver,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        setState(() => _paused = true);
        final leave = await showLeaveGameDialog(context);
        if (leave == true && context.mounted) {
          Navigator.of(context).pop();
          return;
        }
        if (mounted) {
          setState(() => _paused = false);
          _afterTurnAdvance();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ludo Nexus'),
          backgroundColor: const Color(0xFF2A3E66),
          foregroundColor: Colors.white,
        ),
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                PlayerChipsRow(
                  players: engine.players,
                  activeColor: current.color,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: BoardWidget(
                        players: engine.players,
                        movablePieceKeys: movableKeys,
                        onPieceTap: _onPieceTap,
                        activeColor: current.color,
                        finishedRanks: finishedRanks,
                        walkingFractions: _walkingFractions,
                        diceBuilder: (size) => GestureDetector(
                          onTap: _canHumanRoll ? _rollForHuman : null,
                          child: DiceWidget(
                            value: engine.lastRoll,
                            rolling: _diceSpinning,
                            color: current.color,
                            size: size,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: gameOver
                          ? () => Navigator.of(context).pop()
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            bottomText,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
