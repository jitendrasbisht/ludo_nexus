import 'package:flutter/material.dart';

/// Replaces the old static PNG "1ST/2ND/3RD/LAST PLACE" ribbon cards with a
/// crown drawn directly on the canvas -- no card background/border of its
/// own, just the crown and its label sitting on the player's own yard
/// (which already has its own color/border via BoardPainter._paintYard).
///
/// The crown shape and color are keyed purely to [rank] (gold king, silver
/// queen, bronze prince, plain coronet for anything worse) -- entirely
/// independent of which player color earned it, so a yellow player's 1st
/// place still gets the same gold king crown a red player's would.
class FinishCrownBadge extends StatelessWidget {
  final int rank;

  const FinishCrownBadge({super.key, required this.rank});

  static const Map<int, _CrownStyle> _styles = {
    1: _CrownStyle(top: Color(0xFFFFE9A8), bottom: Color(0xFFE0A324), title: '1ST PLACE'),
    2: _CrownStyle(top: Color(0xFFF2A0C4), bottom: Color(0xFFC43C74), title: '2ND PLACE'),
    3: _CrownStyle(top: Color(0xFFF3C9A0), bottom: Color(0xFFB3672F), title: '3RD PLACE'),
  };
  static const _lastStyle = _CrownStyle(top: Color(0xFFD9C9F0), bottom: Color(0xFF8A5CD6), title: 'LAST PLACE');

  @override
  Widget build(BuildContext context) {
    final style = _styles[rank] ?? _lastStyle;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: side * 0.72,
              height: side * 0.58,
              child: CustomPaint(painter: _CrownPainter(rank: rank, style: style)),
            ),
            SizedBox(height: side * 0.06),
            Text(
              style.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: side * 0.1,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2A2A2A),
                letterSpacing: 0.3,
                shadows: const [Shadow(color: Colors.white70, offset: Offset(0, 1))],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CrownStyle {
  final Color top;
  final Color bottom;
  final String title;

  const _CrownStyle({required this.top, required this.bottom, required this.title});
}

class _CrownPainter extends CustomPainter {
  final int rank;
  final _CrownStyle style;

  _CrownPainter({required this.rank, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 80);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [style.top, style.bottom],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 80));
    final outline = Paint()
      ..color = const Color(0xFF1B1B1B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    switch (rank) {
      case 1:
        _paintKing(canvas, fill, outline);
        break;
      case 2:
        _paintQueen(canvas, fill, outline);
        break;
      case 3:
        _paintPrince(canvas, fill, outline);
        break;
      default:
        _paintCoronet(canvas, fill, outline);
    }

    canvas.restore();
  }

  void _paintKing(Canvas canvas, Paint fill, Paint outline) {
    final crown = Path()
      ..moveTo(15, 78)
      ..lineTo(15, 46)
      ..lineTo(23.75, 58)
      ..lineTo(32.5, 32)
      ..lineTo(41.25, 58)
      ..lineTo(50, 18)
      ..lineTo(58.75, 58)
      ..lineTo(67.5, 32)
      ..lineTo(76.25, 58)
      ..lineTo(85, 46)
      ..lineTo(85, 78)
      ..close();
    canvas.drawPath(crown, fill);
    canvas.drawPath(crown, outline);

    final band = RRect.fromRectAndRadius(const Rect.fromLTWH(15, 66, 70, 12), const Radius.circular(2));
    canvas.drawRRect(band, fill);
    canvas.drawRRect(band, outline);

    canvas.drawCircle(const Offset(50, 18), 5, Paint()..color = const Color(0xFFFFF8E0));
    canvas.drawCircle(const Offset(50, 18), 5, outline..strokeWidth = 2.5);
    _gem(canvas, const Offset(32.5, 46), const Color(0xFF4E8FE8));
    _gem(canvas, const Offset(50, 42), const Color(0xFFE8534E));
    _gem(canvas, const Offset(67.5, 46), const Color(0xFF5AC478));
  }

  void _paintQueen(Canvas canvas, Paint fill, Paint outline) {
    final crown = Path()
      ..moveTo(18, 78)
      ..lineTo(18, 50)
      ..quadraticBezierTo(18, 28, 32, 42)
      ..quadraticBezierTo(42, 18, 50, 42)
      ..quadraticBezierTo(58, 18, 68, 42)
      ..quadraticBezierTo(82, 28, 82, 50)
      ..lineTo(82, 78)
      ..close();
    canvas.drawPath(crown, fill);
    canvas.drawPath(crown, outline);

    final band = RRect.fromRectAndRadius(const Rect.fromLTWH(18, 66, 64, 12), const Radius.circular(2));
    canvas.drawRRect(band, fill);
    canvas.drawRRect(band, outline);

    final diamond = Path()
      ..moveTo(50, 16)
      ..lineTo(54, 22)
      ..lineTo(50, 28)
      ..lineTo(46, 22)
      ..close();
    canvas.drawPath(diamond, Paint()..color = Colors.white);
    canvas.drawPath(diamond, outline..strokeWidth = 2);
    _gem(canvas, const Offset(32, 44), const Color(0xFF7A1F45), radius: 3);
    _gem(canvas, const Offset(68, 44), const Color(0xFF7A1F45), radius: 3);
  }

  void _paintPrince(Canvas canvas, Paint fill, Paint outline) {
    final crown = Path()
      ..moveTo(22, 76)
      ..lineTo(22, 50)
      ..lineTo(35, 60)
      ..lineTo(50, 30)
      ..lineTo(65, 60)
      ..lineTo(78, 50)
      ..lineTo(78, 76)
      ..close();
    canvas.drawPath(crown, fill);
    canvas.drawPath(crown, outline);

    final band = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 66, 56, 12), const Radius.circular(2));
    canvas.drawRRect(band, fill);
    canvas.drawRRect(band, outline);

    canvas.drawCircle(const Offset(50, 30), 4, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(50, 30), 4, outline..strokeWidth = 2);
  }

  void _paintCoronet(Canvas canvas, Paint fill, Paint outline) {
    final band = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 58, 48, 18), const Radius.circular(4));
    canvas.drawRRect(band, fill);
    canvas.drawRRect(band, outline);

    canvas.drawCircle(const Offset(50, 52), 5, fill);
    canvas.drawCircle(const Offset(50, 52), 5, outline..strokeWidth = 2.5);
  }

  void _gem(Canvas canvas, Offset center, Color color, {double radius = 3.4}) {
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF1B1B1B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => oldDelegate.rank != rank;
}
