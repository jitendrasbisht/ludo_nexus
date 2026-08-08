import 'dart:math';

import 'package:flutter/material.dart';

import '../game/board_layout.dart';
import '../models/player_color.dart';
import 'ludo_colors.dart';

/// Draws the static Ludo board (yards, 52-cell track, safe cells, home
/// stretches, center hub) using [BoardLayout]'s fractional geometry.
///
/// Pieces themselves are rendered separately as positioned widgets (see
/// BoardWidget) so photo avatars and tap targets stay ordinary widgets
/// rather than hand-rolled hit-testing on a canvas.
class BoardPainter extends CustomPainter {
  /// The current player's yard is drawn brighter with a bolder border; the
  /// other three are dimmed. This is the on-board stand-in for a separate
  /// "whose turn" banner.
  final PlayerColor? activeColor;

  const BoardPainter({this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, Offset.zero & size);
    for (final color in PlayerColor.values) {
      _paintYard(canvas, size, color);
    }
    _paintTrack(canvas, size);
    for (final color in PlayerColor.values) {
      _paintHomeStretch(canvas, size, color);
    }
    _paintCenterHub(canvas, size);
  }

  /// Sharp-cornered, dark-blue-bordered "brick" style for the track and
  /// home-stretch cells, replacing the earlier warm rounded-corner look.
  static const Color _cellBorder = Color(0xFF2B4A8A);

  void _paintBackground(Canvas canvas, Rect fullCanvas) {
    canvas.drawRect(
      fullCanvas,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3E2C0), Color(0xFFE7CE9F)],
        ).createShader(fullCanvas),
    );
    final side = fullCanvas.width;
    final border = Rect.fromPoints(
      BoardLayout.toCanvas(Offset.zero, side),
      BoardLayout.toCanvas(const Offset(1, 1), side),
    ).inflate(side * 0.012);
    canvas.drawRRect(
      RRect.fromRectAndRadius(border, Radius.circular(side * 0.015)),
      Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintYard(Canvas canvas, Size size, PlayerColor color) {
    final side = size.width;
    final r = BoardLayout.yardRect(color);
    final topLeft = BoardLayout.toCanvas(Offset(r[0], r[1]), side);
    final rect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      BoardLayout.scaleLength(r[2], side),
      BoardLayout.scaleLength(r[3], side),
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(side * 0.03));
    final isActive = activeColor == color;
    final dimmed = activeColor != null && !isActive;

    canvas.drawRRect(rrect, Paint()..color = color.material.withValues(alpha: dimmed ? 0.08 : 0.22));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.material.withValues(alpha: dimmed ? 0.35 : 1.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * (isActive ? 0.018 : 0.008),
    );

    final innerRect = rect.deflate(rect.width * 0.09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(side * 0.02)),
      Paint()..color = Colors.white,
    );
    for (final slot in BoardLayout.baseSlots(color)) {
      canvas.drawCircle(
        BoardLayout.toCanvas(slot, side),
        side * 0.028,
        Paint()..color = color.material.withValues(alpha: 0.35),
      );
    }
  }

  void _paintTrack(Canvas canvas, Size size) {
    final side = size.width;
    final points = BoardLayout.trackPoints();
    // Track cells now sit on an actual 15x15 grid (see BoardLayout), so
    // every step -- straight or turning a corner -- is exactly 1/15 of
    // the board apart. A single uniform size this close to that spacing
    // sits fully adjacent everywhere, with no corner-only overlap.
    final cellSize = BoardLayout.scaleLength(1 / 15, side);
    final safe = BoardLayout.safeGlobalIndices;

    for (var i = 0; i < points.length; i++) {
      final p = BoardLayout.toCanvas(points[i], side);
      final cellRect = Rect.fromCenter(center: p, width: cellSize, height: cellSize);

      var fill = Colors.white;
      var isStart = false;
      for (final color in PlayerColor.values) {
        if (BoardLayout.startGlobalIndex(color) == i) {
          fill = color.material;
          isStart = true;
        }
      }
      canvas.drawRect(cellRect, Paint()..color = fill);
      canvas.drawRect(cellRect, Paint()..color = _cellBorder..style = PaintingStyle.stroke..strokeWidth = 1.2);

      if (isStart) {
        // A clearly legible marker (not just a translucent tint) so the
        // entry cell for each color reads at a glance.
        canvas.drawCircle(p, cellSize * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.9));
        canvas.drawCircle(
          p,
          cellSize * 0.3,
          Paint()
            ..color = fill
            ..style = PaintingStyle.stroke
            ..strokeWidth = cellSize * 0.1,
        );
      }

      if (safe.contains(i)) {
        _paintCompassMarker(canvas, p, cellSize * 0.4);
      }
    }
  }

  /// A small 4-point compass-rose star marking a safe cell, in place of a
  /// plain dot -- a classic Ludo-board decoration.
  void _paintCompassMarker(Canvas canvas, Offset center, double outerRadius) {
    canvas.drawCircle(center, outerRadius * 1.05, Paint()..color = Colors.white.withValues(alpha: 0.9));
    final star = _starPath(center, outerRadius, outerRadius * 0.3, 4);
    canvas.drawPath(star, Paint()..color = const Color(0xFF4A4A4A).withValues(alpha: 0.85));
    canvas.drawPath(
      star,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  Path _starPath(Offset center, double outerRadius, double innerRadius, int points) {
    final path = Path();
    final step = pi / points;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = i * step - pi / 2;
      final point = center + Offset(cos(angle), sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  void _paintHomeStretch(Canvas canvas, Size size, PlayerColor color) {
    final side = size.width;
    final points = BoardLayout.homeStretchPoints(color);
    // Sized from the actual spacing between these evenly-interpolated
    // points, so these cells sit adjacent too, matching the track style.
    final stepFraction = (points[1] - points[0]).distance;
    final cellSize = BoardLayout.scaleLength(stepFraction, side);
    for (final p in points) {
      final center = BoardLayout.toCanvas(p, side);
      final rect = Rect.fromCenter(center: center, width: cellSize, height: cellSize);
      canvas.drawRect(rect, Paint()..color = color.material.withValues(alpha: 0.7));
      canvas.drawRect(rect, Paint()..color = _cellBorder..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
  }

  /// Warm cream used for the hub's border and center star, echoing the
  /// board's own wood-tone palette instead of a hard black outline.
  static const Color _hubCream = Color(0xFFFDF8EC);

  /// The center hub is split into 4 triangular wedges, clipped to a
  /// rounded square (matching the board's rounded-cell language) with a
  /// cream border and a small cream compass star at its center. Rather
  /// than hard-code which physical side belongs to which color, each
  /// color's wedge is picked by the actual direction its home stretch
  /// approaches from, so this stays correct regardless of how
  /// BoardLayout's perimeter walk is oriented.
  void _paintCenterHub(Canvas canvas, Size size) {
    const tl = Offset(0.4, 0.4);
    const tr = Offset(0.6, 0.4);
    const br = Offset(0.6, 0.6);
    const bl = Offset(0.4, 0.6);
    const center = Offset(0.5, 0.5);

    Offset px(Offset f) => BoardLayout.toCanvas(f, size.width);
    final side = size.width;
    final hubRect = Rect.fromPoints(px(tl), px(br));
    final hubRRect = RRect.fromRectAndRadius(hubRect, Radius.circular(hubRect.width * 0.22));

    canvas.save();
    canvas.clipRRect(hubRRect);
    for (final color in PlayerColor.values) {
      final entry = BoardLayout.homeStretchPoints(color).first;
      final dx = entry.dx - 0.5;
      final dy = entry.dy - 0.5;
      final List<Offset> tri;
      if (dy.abs() >= dx.abs()) {
        tri = dy < 0 ? [tl, tr, center] : [br, bl, center];
      } else {
        tri = dx < 0 ? [bl, tl, center] : [tr, br, center];
      }
      final path = Path()
        ..moveTo(px(tri[0]).dx, px(tri[0]).dy)
        ..lineTo(px(tri[1]).dx, px(tri[1]).dy)
        ..lineTo(px(tri[2]).dx, px(tri[2]).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color.material);
    }
    canvas.restore();

    canvas.drawRRect(
      hubRRect,
      Paint()
        ..color = _hubCream
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.01,
    );

    final starOuter = hubRect.width * 0.14;
    canvas.drawPath(
      _starPath(px(center), starOuter, starOuter * 0.32, 4),
      Paint()..color = _hubCream,
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => oldDelegate.activeColor != activeColor;
}
