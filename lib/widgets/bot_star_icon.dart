import 'package:flutter/material.dart';

import '../models/player_color.dart';
import 'ludo_colors.dart';

/// A star badge for a bot slot -- filled with that slot's own player
/// color and always outlined in black for contrast, so it reads clearly
/// regardless of the color (unlike, say, a plain yellow icon on a light
/// background). Recolors automatically if the slot's color is swapped.
class BotStarIcon extends StatelessWidget {
  final PlayerColor color;
  final double size;

  const BotStarIcon({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StarPainter(color.material)),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color fillColor;

  _StarPainter(this.fillColor);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final star = Path()
      ..moveTo(50, 6)
      ..lineTo(61, 38)
      ..lineTo(95, 38)
      ..lineTo(67, 58)
      ..lineTo(78, 90)
      ..lineTo(50, 70)
      ..lineTo(22, 90)
      ..lineTo(33, 58)
      ..lineTo(5, 38)
      ..lineTo(39, 38)
      ..close();
    canvas.drawPath(star, Paint()..color = fillColor);
    canvas.drawPath(
      star,
      Paint()
        ..color = const Color(0xFF1B1B1B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => oldDelegate.fillColor != fillColor;
}
