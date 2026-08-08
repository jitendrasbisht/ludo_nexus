import 'package:flutter/material.dart';

import '../game/ai_bot.dart';
import '../game/dice_roller.dart';
import '../game/ludo_engine.dart';
import '../models/bot_difficulty.dart';
import '../models/piece.dart';
import '../models/player.dart';
import '../services/click_sound.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/ludo_colors.dart';
import '../widgets/piece_avatar.dart';
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
  Piece? _walkingPiece;
  Offset? _walkingFraction;
  bool _diceSpinning = false;

  @override
  void initState() {
    super.initState();
    engine = widget.engine;
    _statusText = '${engine.currentPlayer.name}, roll to start!';
    ClickSound.preload();
    _afterTurnAdvance();
  }

  bool get _canHumanRoll =>
      !engine.gameOver && !_busy && !engine.currentPlayer.isBot && _movable.isEmpty;

  /// Spins the dice face through random values briefly before actually
  /// rolling, so the roll is something the player visibly watches happen
  /// rather than a number just appearing.
  Future<int> _rollWithAnimation() async {
    setState(() => _diceSpinning = true);
    await Future.delayed(const Duration(milliseconds: 550));
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
      setState(() => _statusText = '${mover.name} rolled three 6s in a row -- turn forfeited!');
      await Future.delayed(const Duration(milliseconds: 900));
      engine.skipTurn();
      setState(() => _busy = false);
      _afterTurnAdvance();
      return;
    }

    final movable = engine.movablePieces(value);
    if (movable.isEmpty) {
      setState(() => _statusText = '${mover.name} rolled a $value -- no legal moves.');
      await Future.delayed(const Duration(milliseconds: 900));
      engine.skipTurn();
      setState(() => _busy = false);
      _afterTurnAdvance();
      return;
    }

    if (movable.length == 1) {
      setState(() => _statusText = '${mover.name} rolled a $value.');
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
        if (i < diceValue - 1) await Future.delayed(const Duration(milliseconds: 160));
      }
      return;
    }

    for (var step = 1; step <= diceValue; step++) {
      final pos = startPos + step;
      if (pos > 57) break;
      if (!mounted) return;
      setState(() {
        _walkingPiece = piece;
        _walkingFraction = fractionForPiecePosition(piece.color, pos);
      });
      ClickSound.play();
      await Future.delayed(const Duration(milliseconds: 380));
    }
  }

  Future<void> _applyMove(Piece piece, int diceValue, String moverName) async {
    setState(() {
      _busy = true;
      _movable = [];
    });

    await _walkPiece(piece, diceValue);
    if (!mounted) return;
    final result = engine.movePiece(piece, diceValue);
    setState(() {
      _walkingPiece = null;
      _walkingFraction = null;
      if (result.capturedPieces.isNotEmpty) {
        _statusText = '$moverName captured ${result.capturedPieces.length} piece(s)!';
      } else if (result.finishedPiece) {
        _statusText = '$moverName got a piece home!';
      } else {
        _statusText = "$moverName's turn continues...";
      }
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.wonGame) {
      _showWinDialog();
      return;
    }
    _afterTurnAdvance();
  }

  void _afterTurnAdvance() {
    if (!mounted) return;
    setState(() {});
    if (!engine.gameOver && engine.currentPlayer.isBot) {
      Future.delayed(const Duration(milliseconds: 700), _playBotTurn);
    }
  }

  Future<void> _playBotTurn() async {
    if (!mounted || engine.gameOver) return;
    final bot = engine.currentPlayer;
    if (!bot.isBot) return; // stale callback from a replayed game

    setState(() => _busy = true);
    final value = await _rollWithAnimation();
    if (!mounted) return;
    setState(() => _statusText = '${bot.name} rolled a $value.');
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (engine.mustForfeitTurn) {
      setState(() => _statusText = '${bot.name} rolled three 6s -- turn forfeited!');
      await Future.delayed(const Duration(milliseconds: 700));
      engine.skipTurn();
      setState(() => _busy = false);
      _afterTurnAdvance();
      return;
    }

    final movable = engine.movablePieces(value);
    if (movable.isEmpty) {
      setState(() => _statusText = '${bot.name} has no legal moves.');
      await Future.delayed(const Duration(milliseconds: 700));
      engine.skipTurn();
      setState(() => _busy = false);
      _afterTurnAdvance();
      return;
    }

    final piece = AiBot.choosePiece(engine, movable, bot.botDifficulty ?? BotDifficulty.medium, value);
    await _walkPiece(piece, value);
    if (!mounted) return;
    final result = engine.movePiece(piece, value);
    setState(() {
      _walkingPiece = null;
      _walkingFraction = null;
      if (result.capturedPieces.isNotEmpty) {
        _statusText = '${bot.name} captured a piece!';
      } else if (result.finishedPiece) {
        _statusText = '${bot.name} got a piece home!';
      } else {
        _statusText = '${bot.name} moved.';
      }
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.wonGame) {
      _showWinDialog();
      return;
    }
    _afterTurnAdvance();
  }

  void _showWinDialog() {
    final winner = engine.winner!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('We have a winner!'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PieceAvatar(
              color: winner.color,
              size: 56,
              photoPath: winner.photoPath,
              initial: winner.name.isNotEmpty ? winner.name[0].toUpperCase() : '?',
              isBot: winner.isBot,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text('${winner.name} wins the game!')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Setup'),
          ),
          FilledButton(onPressed: _replay, child: const Text('Play Again')),
        ],
      ),
    );
  }

  void _replay() {
    Navigator.of(context).pop();
    final freshPlayers = [
      for (final p in engine.players)
        LudoPlayer(
          color: p.color,
          name: p.name,
          isBot: p.isBot,
          botDifficulty: p.botDifficulty,
          photoPath: p.photoPath,
        ),
    ];
    setState(() {
      engine = LudoEngine(players: freshPlayers);
      _movable = [];
      _busy = false;
      _statusText = '${engine.currentPlayer.name}, roll to start!';
    });
    _afterTurnAdvance();
  }

  void _showRollHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Roll History'),
        content: SizedBox(width: double.maxFinite, child: _RollHistoryPanel(dice: engine.dice)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = engine.currentPlayer;
    final movableKeys = {
      for (final p in _movable) BoardWidget.pieceKey(p.color, p.id),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo'),
        backgroundColor: current.color.material,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Roll history',
            onPressed: _showRollHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            PlayerChipsRow(players: engine.players, activeColor: current.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: BoardWidget(
                    players: engine.players,
                    movablePieceKeys: movableKeys,
                    onPieceTap: _onPieceTap,
                    activeColor: current.color,
                    walkingPiece: _walkingPiece,
                    walkingFraction: _walkingFraction,
                    diceBuilder: (size) => GestureDetector(
                      onTap: _canHumanRoll ? _rollForHuman : null,
                      child: DiceWidget(value: engine.lastRoll, rolling: _diceSpinning, size: size),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                _statusText.isEmpty ? 'Tap your dice to roll' : _statusText,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A roll log + per-face frequency count -- the transparent "provably
/// fair" trust feature backing DiceRoller, shown on demand via the app
/// bar's history icon rather than as a permanent on-screen panel.
class _RollHistoryPanel extends StatelessWidget {
  final DiceRoller dice;

  const _RollHistoryPanel({required this.dice});

  @override
  Widget build(BuildContext context) {
    final freq = dice.frequency;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, size: 16),
              SizedBox(width: 6),
              Text('Roll history (fair dice -- nothing hidden)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 26,
            child: dice.history.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No rolls yet.', style: TextStyle(fontSize: 12)),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    children: [
                      for (final v in dice.history.reversed.take(40))
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$v', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              for (final face in [1, 2, 3, 4, 5, 6]) Text('$face ×${freq[face]}', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
