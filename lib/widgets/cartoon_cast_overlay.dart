import 'package:flutter/material.dart';

/// A single (time, value) waypoint in a character's animation cycle.
/// [t] is a fraction (0..1) of that character's full loop duration --
/// mirrors a CSS `@keyframes` percentage stop.
class _Stop {
  final double t;
  final double v;
  const _Stop(this.t, this.v);
}

/// Linearly interpolates (eased) between the two [stops] bracketing [t].
double _at(List<_Stop> stops, double t) {
  if (stops.isEmpty) return 0;
  if (t <= stops.first.t) return stops.first.v;
  if (t >= stops.last.t) return stops.last.v;
  for (var i = 0; i < stops.length - 1; i++) {
    final a = stops[i], b = stops[i + 1];
    if (t >= a.t && t <= b.t) {
      final localT = (b.t - a.t) == 0 ? 0.0 : (t - a.t) / (b.t - a.t);
      final eased = Curves.easeInOut.transform(localT.clamp(0.0, 1.0));
      return a.v + (b.v - a.v) * eased;
    }
  }
  return stops.last.v;
}

/// One animated character's full recipe: where it's anchored, how big it
/// is, its loop duration/phase offset, and the opacity/position/scale/
/// rotation curve it follows through that loop (each expressed as
/// fractions of the overlay's own size, the same way the original CSS
/// POC used percentage-based keyframes).
class _MascotSpec {
  final Duration duration;
  final double phaseSeconds;
  final double anchorX;
  final double anchorY;
  final double width;
  final double height;
  final List<_Stop> opacity;
  final List<_Stop> dx;
  final List<_Stop> dy;
  final List<_Stop> scale;
  final List<_Stop> rotationDeg;
  final WidgetBuilder builder;

  const _MascotSpec({
    required this.duration,
    required this.phaseSeconds,
    required this.anchorX,
    required this.anchorY,
    required this.width,
    required this.height,
    required this.opacity,
    required this.builder,
    this.dx = const [_Stop(0, 0), _Stop(1, 0)],
    this.dy = const [_Stop(0, 0), _Stop(1, 0)],
    this.scale = const [_Stop(0, 1), _Stop(1, 1)],
    this.rotationDeg = const [_Stop(0, 0), _Stop(1, 0)],
  });
}

/// Decorative animated cast for the Cartoon kids theme -- a princess photo
/// drifting continuously top-to-bottom, plus 4 original mascot characters
/// each entering/holding/exiting on their own independent loop (a Bounce,
/// a Fly-In, a Spin, and a Zoom -- PowerPoint-style entrance effects).
/// Purely decorative: sits behind the real UI and never intercepts taps.
class CartoonCastOverlay extends StatefulWidget {
  const CartoonCastOverlay({super.key});

  @override
  State<CartoonCastOverlay> createState() => _CartoonCastOverlayState();
}

class _CartoonCastOverlayState extends State<CartoonCastOverlay> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<_MascotSpec> _specs;

  @override
  void initState() {
    super.initState();
    _specs = _buildSpecs();
    _controllers = [
      for (final spec in _specs) AnimationController(vsync: this, duration: spec.duration)..repeat(),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<_MascotSpec> _buildSpecs() {
    return [
      // Princess -- continuous top-to-bottom descent with a gentle sway.
      _MascotSpec(
        duration: const Duration(seconds: 11),
        phaseSeconds: 0,
        anchorX: 0.5,
        anchorY: 0,
        width: 92,
        height: 118,
        opacity: const [_Stop(0, 0), _Stop(0.08, 1), _Stop(0.80, 1), _Stop(0.96, 0), _Stop(1, 0)],
        dx: const [_Stop(0, 0), _Stop(0.30, -0.05), _Stop(0.55, 0.05), _Stop(0.80, -0.04), _Stop(1, 0)],
        dy: const [_Stop(0, -0.09), _Stop(0.30, 0.20), _Stop(0.55, 0.48), _Stop(0.80, 0.74), _Stop(1, 0.87)],
        rotationDeg: const [_Stop(0, -3), _Stop(0.30, 2), _Stop(0.55, -2), _Stop(0.80, 2), _Stop(1, -3)],
        builder: (context) => const _PrincessCard(),
      ),
      // Dino -- bounces in from above, settles, holds, drops back out.
      _MascotSpec(
        duration: const Duration(seconds: 12),
        phaseSeconds: 2,
        anchorX: 0.15,
        anchorY: 0.86,
        width: 74,
        height: 60,
        opacity: const [_Stop(0, 0), _Stop(0.09, 1), _Stop(0.80, 1), _Stop(0.92, 0), _Stop(1, 0)],
        dy: const [
          _Stop(0, -0.30), _Stop(0.09, -0.30), _Stop(0.22, 0), _Stop(0.30, -0.08),
          _Stop(0.38, 0), _Stop(0.44, -0.035), _Stop(0.50, 0), _Stop(0.80, 0),
          _Stop(0.92, 0.03), _Stop(1, -0.30),
        ],
        builder: (context) => const _DinoArt(),
      ),
      // Bear -- flies in from the right, holds, flies back out to the left.
      _MascotSpec(
        duration: const Duration(seconds: 14),
        phaseSeconds: 5,
        anchorX: 0.86,
        anchorY: 0.84,
        width: 66,
        height: 60,
        opacity: const [_Stop(0, 0), _Stop(0.14, 1), _Stop(0.76, 1), _Stop(0.90, 0), _Stop(1, 0)],
        dx: const [
          _Stop(0, 0.55), _Stop(0.14, -0.03), _Stop(0.20, 0), _Stop(0.76, 0), _Stop(0.90, -0.55), _Stop(1, 0.55),
        ],
        rotationDeg: const [
          _Stop(0, 8), _Stop(0.14, -2), _Stop(0.20, 0), _Stop(0.76, 0), _Stop(0.90, -8), _Stop(1, 8),
        ],
        builder: (context) => const _BearArt(),
      ),
      // Star-buddy -- spins in, holds, spins back out.
      _MascotSpec(
        duration: const Duration(seconds: 12),
        phaseSeconds: 1,
        anchorX: 0.84,
        anchorY: 0.14,
        width: 46,
        height: 46,
        opacity: const [_Stop(0, 0), _Stop(0.16, 1), _Stop(0.78, 1), _Stop(0.90, 0), _Stop(1, 0)],
        scale: const [
          _Stop(0, 0.2), _Stop(0.16, 1.05), _Stop(0.22, 1), _Stop(0.78, 1), _Stop(0.90, 0.3), _Stop(1, 0.2),
        ],
        rotationDeg: const [
          _Stop(0, -260), _Stop(0.16, 10), _Stop(0.22, 0), _Stop(0.78, 0), _Stop(0.90, 220), _Stop(1, -260),
        ],
        builder: (context) => const _StarBuddyArt(),
      ),
      // Puff critter -- zooms in from nothing, holds, zooms back out.
      _MascotSpec(
        duration: const Duration(seconds: 10, milliseconds: 500),
        phaseSeconds: 3.5,
        anchorX: 0.14,
        anchorY: 0.12,
        width: 54,
        height: 46,
        opacity: const [_Stop(0, 0), _Stop(0.12, 1), _Stop(0.75, 1), _Stop(0.88, 0), _Stop(1, 0)],
        scale: const [
          _Stop(0, 0), _Stop(0.12, 1.18), _Stop(0.18, 0.95), _Stop(0.24, 1),
          _Stop(0.75, 1), _Stop(0.88, 0.3), _Stop(1, 0),
        ],
        builder: (context) => const _PuffArt(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              for (var i = 0; i < _specs.length; i++)
                AnimatedBuilder(
                  animation: _controllers[i],
                  builder: (context, child) {
                    final spec = _specs[i];
                    final periodSeconds = spec.duration.inMilliseconds / 1000;
                    final phaseFrac = (spec.phaseSeconds / periodSeconds) % 1.0;
                    final t = (_controllers[i].value + phaseFrac) % 1.0;

                    final opacity = _at(spec.opacity, t).clamp(0.0, 1.0);
                    if (opacity <= 0.001) return const SizedBox.shrink();

                    final centerX = spec.anchorX * w + _at(spec.dx, t) * w;
                    final centerY = spec.anchorY * h + _at(spec.dy, t) * h;
                    final scale = _at(spec.scale, t);
                    final rotation = _at(spec.rotationDeg, t) * 3.1415926535 / 180;

                    return Positioned(
                      left: centerX - spec.width / 2,
                      top: centerY - spec.height / 2,
                      width: spec.width,
                      height: spec.height,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(
                            scale: scale,
                            child: spec.builder(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PrincessCard extends StatelessWidget {
  const _PrincessCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset('assets/background/Animation.png', fit: BoxFit.cover),
      ),
    );
  }
}

class _DinoArt extends StatelessWidget {
  const _DinoArt();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DinoPainter(), size: Size.infinite);
}

class _DinoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 80);
    final green = Paint()..color = const Color(0xFF7ED166);
    final darkGreen = Paint()..color = const Color(0xFF5AA64A);
    canvas.drawOval(const Rect.fromLTWH(-2, 39, 32, 14), darkGreen);
    canvas.drawOval(const Rect.fromLTWH(35, 44, 14, 28), darkGreen);
    canvas.drawOval(const Rect.fromLTWH(59, 44, 14, 28), darkGreen);
    canvas.drawOval(const Rect.fromLTWH(21, 18, 68, 48), green);
    canvas.drawPath(Path()..moveTo(30, 24)..lineTo(38, 8)..lineTo(44, 26)..close(), darkGreen);
    canvas.drawPath(Path()..moveTo(44, 20)..lineTo(51, 4)..lineTo(57, 22)..close(), darkGreen);
    canvas.drawCircle(const Offset(80, 28), 18, green);
    canvas.drawCircle(const Offset(86, 24), 3.4, Paint()..color = const Color(0xFF2A2140));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BearArt extends StatelessWidget {
  const _BearArt();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BearPainter(), size: Size.infinite);
}

class _BearPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 92);
    final fur = Paint()..color = const Color(0xFFC08A5C);
    final ear = Paint()..color = const Color(0xFFA9764F);
    final snout = Paint()..color = const Color(0xFFE3B593);
    canvas.drawCircle(const Offset(26, 20), 12, ear);
    canvas.drawCircle(const Offset(74, 20), 12, ear);
    canvas.drawCircle(const Offset(26, 20), 6, snout);
    canvas.drawCircle(const Offset(74, 20), 6, snout);
    canvas.drawOval(const Rect.fromLTWH(12, 18, 76, 68), fur);
    canvas.drawOval(const Rect.fromLTWH(32, 48, 36, 28), snout);
    canvas.drawCircle(const Offset(38, 44), 3.6, Paint()..color = const Color(0xFF2A2140));
    canvas.drawCircle(const Offset(62, 44), 3.6, Paint()..color = const Color(0xFF2A2140));
    canvas.drawOval(const Rect.fromLTWH(45, 54.5, 10, 7), Paint()..color = const Color(0xFF5A3A24));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarBuddyArt extends StatelessWidget {
  const _StarBuddyArt();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StarBuddyPainter(), size: Size.infinite);
}

class _StarBuddyPainter extends CustomPainter {
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
    canvas.drawPath(star, Paint()..color = const Color(0xFFC9A8F0));
    canvas.drawPath(
      star,
      Paint()
        ..color = const Color(0xFF8A5CD6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(42, 48), 4.6, Paint()..color = const Color(0xFF3A2140));
    canvas.drawCircle(const Offset(60, 48), 4.6, Paint()..color = const Color(0xFF3A2140));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PuffArt extends StatelessWidget {
  const _PuffArt();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PuffPainter(), size: Size.infinite);
}

class _PuffPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 110, size.height / 90);
    final body = Paint()..color = const Color(0xFFFFB6D9);
    final wing = Paint()..color = const Color(0xFFFFD9EC);
    canvas.drawOval(const Rect.fromLTWH(2, 32, 32, 20), wing);
    canvas.drawOval(const Rect.fromLTWH(76, 32, 32, 20), wing);
    canvas.drawCircle(const Offset(55, 48), 30, body);
    canvas.drawCircle(const Offset(40, 34), 9, body);
    canvas.drawCircle(const Offset(70, 34), 9, body);
    canvas.drawCircle(const Offset(46, 46), 4, Paint()..color = const Color(0xFF5A2140));
    canvas.drawCircle(const Offset(64, 46), 4, Paint()..color = const Color(0xFF5A2140));
    canvas.drawCircle(const Offset(38, 56), 4.5, Paint()..color = const Color(0xFFFF8FC0).withValues(alpha: 0.7));
    canvas.drawCircle(const Offset(72, 56), 4.5, Paint()..color = const Color(0xFFFF8FC0).withValues(alpha: 0.7));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
