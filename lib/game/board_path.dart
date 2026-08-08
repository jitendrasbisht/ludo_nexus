import '../models/player_color.dart';

/// Shared coordinate/rules math for the 52-cell Ludo outer track plus
/// each color's private 5-cell home stretch (positions 53-57).
///
/// A piece's `position` field (see Piece) is always relative to its own
/// color: 1 is that color's own entry square, counting up from there.
/// This class converts a relative position into a global track index
/// (0-51) so pieces of different colors can be compared to detect
/// captures. The numbering here must stay in sync with BoardLayout
/// (lib/game/board_layout.dart), which is the single source of truth
/// for how the 52-cell ring is divided into 4 equal 13-cell quadrants,
/// one per color.
class BoardPath {
  static const int trackLength = 52;
  static const int cellsPerQuadrant = 13;
  static const int homeStretchStart = 53;
  static const int homeStretchEnd = 57; // 57 == finished

  static int _quadrantIndex(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return 0;
      case PlayerColor.green:
        return 1;
      case PlayerColor.yellow:
        return 2;
      case PlayerColor.blue:
        return 3;
    }
  }

  static int startOffset(PlayerColor color) => _quadrantIndex(color) * cellsPerQuadrant;

  /// The 4 starting squares plus one additional "star" square per color
  /// (roughly midway through their own quadrant) are safe -- no captures
  /// can happen on these cells.
  static Set<int> get safeCells {
    final result = <int>{};
    for (final color in PlayerColor.values) {
      final start = startOffset(color);
      result.add(start);
      result.add(start + 6);
    }
    return result;
  }

  /// Converts a relative position (must be 1..52) into a global 0..51
  /// index on the shared track.
  static int globalIndex(PlayerColor color, int relativePosition) {
    assert(relativePosition >= 1 && relativePosition <= 52);
    return (startOffset(color) + relativePosition - 1) % trackLength;
  }

  static bool isSafeGlobalIndex(int globalIndex) => safeCells.contains(globalIndex);
}
