import 'dart:ui';

import '../models/player_color.dart';

/// Pure geometry for rendering the Ludo board.
///
/// Rather than hand-mapping every one of the 52 track cells to a specific
/// grid row/column (extremely easy to get subtly wrong without being able
/// to render and eyeball it), this walks 52 evenly-spaced points around a
/// cross-shaped perimeter polyline. This guarantees a continuous, valid,
/// closed loop by construction, and still looks like a proper Ludo board:
/// 4 colored yards in the corners, a track running around the cross, and
/// a home stretch leading from each color's own arm into the center.
///
/// All coordinates are fractions (0.0-1.0) of the square board, so the
/// painter can multiply by whatever pixel size it's given.
class BoardLayout {
  static const int trackLength = 52;
  static const int cellsPerQuadrant = 13;

  /// Fractional coordinates run edge-to-edge (0.0-1.0), but several track
  /// points sit exactly on that boundary (e.g. a color's start cell at
  /// x=0). Drawn at actual size, half of a cell centered there would fall
  /// outside the canvas entirely. [margin] reserves a border so every
  /// fractional coordinate maps well inside the drawable area instead.
  static const double margin = 0.035;

  /// Maps a 0.0-1.0 fractional coordinate to a pixel position inset by
  /// [margin], for a square canvas of the given [side]. Both the board
  /// painter and the piece-positioning widget must use this (not raw
  /// fraction*side) so cells and pieces stay aligned.
  static Offset toCanvas(Offset fraction, double side) {
    const inner = 1 - 2 * margin;
    return Offset(
      (margin + fraction.dx * inner) * side,
      (margin + fraction.dy * inner) * side,
    );
  }

  /// Scales a fractional length (e.g. a cell size expressed as a fraction
  /// of the board) down to match [toCanvas]'s inset coordinate space.
  static double scaleLength(double fraction, double side) => fraction * (1 - 2 * margin) * side;

  /// Row/column (0-14) of each of red's 13 track cells on a standard
  /// 15x15 Ludo grid, starting at its own entry square and ending
  /// adjacent to green's. The other 3 colors' cells are this same list
  /// rotated 90/180/270 degrees around the board center -- generated
  /// (see [trackPoints]) rather than hand-copied, so all 4 quadrants are
  /// guaranteed exactly symmetric.
  ///
  /// This replaces an earlier approach that sampled 52 equally-spaced
  /// points along a smooth perimeter curve: mathematically tidy, but on
  /// this cross-shaped path the corners are physically closer together
  /// than a straight run (a corner "cuts" the curve), so cells sized to
  /// sit flush on the straight stretches ended up overlapping right at
  /// every turn. A real grid has no such issue -- every step, corner or
  /// not, is exactly one cell apart by construction.
  static const List<List<int>> _redQuadrant = [
    [6, 1], [6, 2], [6, 3], [6, 4], [6, 5],
    [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6],
    [0, 7], [0, 8],
  ];

  /// Rotates a (row,col) grid cell 90 degrees clockwise around the center
  /// of a 15x15 grid (index 7,7).
  static List<int> _rotate90(List<int> cell) {
    final row = cell[0], col = cell[1];
    return [col, 14 - row];
  }

  static Offset _gridToFraction(List<int> cell) => Offset((cell[1] + 0.5) / 15, (cell[0] + 0.5) / 15);

  /// The 52 track cells in order, red's quadrant then its 90/180/270
  /// degree rotations for green/yellow/blue.
  static List<Offset> trackPoints() {
    var quadrant = _redQuadrant;
    final cells = <List<int>>[];
    for (var q = 0; q < 4; q++) {
      cells.addAll(quadrant);
      quadrant = quadrant.map(_rotate90).toList();
    }
    return cells.map(_gridToFraction).toList();
  }

  static int quadrantIndex(PlayerColor color) {
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

  /// Global track index (0-51) of this color's own entry/start cell.
  static int startGlobalIndex(PlayerColor color) => quadrantIndex(color) * cellsPerQuadrant;

  /// One extra safe "star" cell roughly midway through each color's
  /// own quadrant stretch.
  static int starGlobalIndex(PlayerColor color) => quadrantIndex(color) * cellsPerQuadrant + 6;

  static Set<int> get safeGlobalIndices {
    final result = <int>{};
    for (final color in PlayerColor.values) {
      result.add(startGlobalIndex(color));
      result.add(starGlobalIndex(color));
    }
    return result;
  }

  /// Center of the board (the shared home hub), as a fraction of board size.
  static const Offset center = Offset(0.5, 0.5);

  /// Red's 5 home-stretch grid cells (relative positions 53-57): the
  /// middle lane of its own arm, running from just outside its yard
  /// straight into the center. Rotated the same way as [_redQuadrant]
  /// for the other 3 colors.
  static const List<List<int>> _redHomeStretch = [
    [7, 1], [7, 2], [7, 3], [7, 4], [7, 5],
  ];

  /// 5 grid cells from this color's own arm into the center -- the
  /// private home stretch (relative positions 53-57).
  static List<Offset> homeStretchPoints(PlayerColor color) {
    var cells = _redHomeStretch;
    for (var q = 0; q < quadrantIndex(color); q++) {
      cells = cells.map(_rotate90).toList();
    }
    return cells.map(_gridToFraction).toList();
  }

  /// Where a color's *finished* pieces (position 57) sit once they reach
  /// home, clustered inside that color's own wedge of the center hub
  /// rather than disappearing off the board.
  static List<Offset> finishedSlots(PlayerColor color) {
    final entry = homeStretchPoints(color).first;
    final dx = entry.dx - 0.5;
    final dy = entry.dy - 0.5;
    final Offset outward;
    final Offset lateral;
    if (dy.abs() >= dx.abs()) {
      outward = Offset(0, dy < 0 ? -1 : 1);
      lateral = const Offset(1, 0);
    } else {
      outward = Offset(dx < 0 ? -1 : 1, 0);
      lateral = const Offset(0, 1);
    }
    // Two separate constraints bound this cluster, not just one: it must
    // stay inside the hub's own half-width (0.1) in the outward direction
    // (or it clips the hub's edge), AND it must stay on the correct side
    // of the 45-degree diagonal that separates this color's wedge from
    // its neighbors' (or it collides with another color's finished
    // pieces at the hub's center) -- pulling the cluster closer to center
    // to fix the first problem alone (an earlier pass here) satisfied the
    // edge constraint but violated the diagonal one instead, since moving
    // inward shrinks the *outward* margin while the *lateral* spread
    // stays the same size, tipping the piece's own footprint across the
    // wedge boundary. At this finished-piece size (see the 0.28x scale in
    // BoardWidget) both constraints hold with a few thousandths of margin
    // to spare -- this is close to the largest these can get in a fixed
    // 2x2 grid sized for 4 pieces; meaningfully bigger needs the pieces to
    // shrink dynamically with how many have actually finished instead.
    final base = center + outward * 0.057;
    const out = 0.0165;
    const lat = 0.0165;
    return [
      base + outward * out - lateral * lat,
      base + outward * out + lateral * lat,
      base - outward * out - lateral * lat,
      base - outward * out + lateral * lat,
    ];
  }

  /// Yard (base) rectangle for a color, as a fraction of the board --
  /// left, top, width, height, all 0.0-1.0.
  static List<double> yardRect(PlayerColor color) {
    const inset = 0.02;
    const size = 0.36;
    switch (color) {
      case PlayerColor.red:
        return [inset, inset, size, size];
      case PlayerColor.green:
        return [1 - inset - size, inset, size, size];
      case PlayerColor.yellow:
        return [1 - inset - size, 1 - inset - size, size, size];
      case PlayerColor.blue:
        return [inset, 1 - inset - size, size, size];
    }
  }

  /// Where the dice sits for a color's turn. Red's exact spot was tuned
  /// by eye (38% across its yard from the outer edge, and 12% of the
  /// yard's height poking past the outer edge), then mirrored onto the
  /// other three yards as a true reflection about the board's own
  /// horizontal and vertical center lines -- not a copy-pasted formula --
  /// so all four sit in the equivalent spot relative to their own yard
  /// regardless of which corner it's in.
  static Offset diceAnchor(PlayerColor color) {
    final r = yardRect(color);
    final isLeftYard = r[0] < 0.5;
    final isTopYard = r[1] < 0.5;

    final outerX = isLeftYard ? r[0] : r[0] + r[2];
    final x = isLeftYard ? outerX + r[2] * 0.38 : outerX - r[2] * 0.38;

    final outerY = isTopYard ? r[1] : r[1] + r[3];
    final y = isTopYard ? outerY - r[3] * 0.12 : outerY + r[3] * 0.12;

    return Offset(x, y);
  }

  /// The 4 base-slot positions inside a color's yard where its pieces
  /// sit while still in base, as fractions of the whole board.
  static List<Offset> baseSlots(PlayerColor color) {
    final r = yardRect(color);
    final left = r[0], top = r[1], w = r[2], h = r[3];
    final positions = [
      Offset(left + w * 0.34, top + h * 0.34),
      Offset(left + w * 0.66, top + h * 0.34),
      Offset(left + w * 0.34, top + h * 0.66),
      Offset(left + w * 0.66, top + h * 0.66),
    ];
    return positions;
  }
}
