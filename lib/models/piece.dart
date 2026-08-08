import 'player_color.dart';

/// A single token belonging to a player.
///
/// Position encoding:
///   0        -> still in the base/yard, not on the board
///   1..52    -> on the shared 52-cell outer track, relative to this
///               piece's own entry point (see BoardPath.globalIndex)
///   53..57   -> in the private 5-cell home stretch for this color
///   57       -> reached home, finished
class Piece {
  final int id;
  final PlayerColor color;
  int position;

  Piece({required this.id, required this.color}) : position = 0;

  bool get isInBase => position == 0;
  bool get isFinished => position == 57;
  bool get isInHomeStretch => position >= 53 && position <= 57;
  bool get isOnSharedTrack => position >= 1 && position <= 52;

  Piece copy() => Piece(id: id, color: color)..position = position;

  @override
  String toString() => 'Piece(${color.name}#$id, pos=$position)';
}
