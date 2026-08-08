import 'bot_difficulty.dart';
import 'piece.dart';
import 'player_color.dart';

class LudoPlayer {
  final PlayerColor color;
  String name;
  final bool isBot;
  final BotDifficulty? botDifficulty;

  /// Local file path to the player's chosen photo, or null to fall back
  /// to a plain colored token with the player's initial.
  String? photoPath;

  final List<Piece> pieces;

  LudoPlayer({
    required this.color,
    required this.name,
    this.isBot = false,
    this.botDifficulty,
    this.photoPath,
  }) : pieces = List.generate(4, (i) => Piece(id: i, color: color));

  bool get hasWon => pieces.every((p) => p.isFinished);

  int get piecesInBase => pieces.where((p) => p.isInBase).length;
  int get piecesFinished => pieces.where((p) => p.isFinished).length;
}
