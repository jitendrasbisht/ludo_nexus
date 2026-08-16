import 'dart:math';

import 'package:flutter/material.dart';

/// Shows the "Leave this game?" confirmation as a custom board-themed card
/// instead of a plain Material [AlertDialog] -- a thin Red/Green/Yellow/Blue
/// strip echoes the board's own color quadrants, and the icon reuses the
/// same 4-point compass star [BoardPainter] draws on every safe cell (see
/// `_paintCompassMarker` there), styled gold/glossy here instead of the
/// board's grey. Returns true if the player chose to leave, false/null to
/// stay.
Future<bool?> showLeaveGameDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: _LeaveGameCard(
        onStay: () => Navigator.pop(ctx, false),
        onLeave: () => Navigator.pop(ctx, true),
      ),
    ),
  );
}

class _LeaveGameCard extends StatelessWidget {
  final VoidCallback onStay;
  final VoidCallback onLeave;

  const _LeaveGameCard({required this.onStay, required this.onLeave});

  static const _stripColors = [
    Color(0xFFE21E1E),
    Color(0xFF00B050),
    Color(0xFFF2C200),
    Color(0xFF0090D8),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDF6E6), Color(0xFFF2E6C4)],
          ),
          boxShadow: [
            BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 24)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [for (final c in _stripColors) Expanded(child: Container(height: 10, color: c))],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _GoldStar(size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'Leave this game?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2A3E66)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Going back will cancel the current game in progress.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF6B5A2E)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _DialogButton(label: 'Stay', filled: true, onTap: onStay)),
                      const SizedBox(width: 10),
                      Expanded(child: _DialogButton(label: 'Leave', filled: false, onTap: onLeave)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _DialogButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: filled ? null : Border.all(color: const Color(0x407A5A1F)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: filled
                  ? const [Color(0xFF4A5F92), Color(0xFF1C2C4E)]
                  : const [Color(0xFFFFFDF7), Color(0xFFE8DDC0)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: filled ? 0.3 : 0.9),
                blurRadius: 3,
                blurStyle: BlurStyle.inner,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: filled ? 0.3 : 0.12),
                blurRadius: 6,
                blurStyle: BlurStyle.inner,
                offset: const Offset(0, -5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: filled ? 0.35 : 0.15),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: filled ? Colors.white : const Color(0xFF7A5A1F),
            ),
          ),
        ),
      ),
    );
  }
}

/// The same 4-point compass star [BoardPainter] draws on safe cells, reused
/// here at dialog-icon size with a gold gloss instead of the board's grey.
class _GoldStar extends StatelessWidget {
  final double size;

  const _GoldStar({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoldStarPainter()),
    );
  }
}

class _GoldStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final star = _starPath(center, outerRadius, outerRadius * 0.42, 4);

    canvas.drawPath(
      star.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      star,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFFFF8E0), Color(0xFFE8C86A)],
        ).createShader(Rect.fromCircle(center: center, radius: outerRadius)),
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
