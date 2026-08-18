import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single (time, value) waypoint in a loop, mirroring the same
/// keyframe-stop approach used by [CartoonCastOverlay].
class _Stop {
  final double t;
  final double v;
  const _Stop(this.t, this.v);
}

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

class _MoonSpec {
  final Duration duration;
  final double phaseSeconds;
  final double anchorX;
  final double size;

  const _MoonSpec({
    required this.duration,
    required this.phaseSeconds,
    required this.anchorX,
    required this.size,
  });
}

class _StarSpec {
  final double baseX;
  final double baseY;
  final double ampX;
  final double ampY;
  final double freqX;
  final double freqY;
  final double phase;
  final double size;
  final bool sparkle; // true = 4-point star shape, false = plain dot

  const _StarSpec({
    required this.baseX,
    required this.baseY,
    required this.ampX,
    required this.ampY,
    required this.freqX,
    required this.freqY,
    required this.phase,
    required this.size,
    required this.sparkle,
  });
}

/// Decorative animated overlay for the Night Sky kids theme: 3 moons that
/// continuously descend top-to-bottom (same loop shape as the Cartoon
/// theme's princess), each at a different size/speed/phase so they never
/// move in lockstep, plus a field of stars that drift in small wandering
/// loops instead of only twinkling in place. Purely decorative -- ignores
/// pointer events so it never blocks taps.
class NightCastOverlay extends StatefulWidget {
  const NightCastOverlay({super.key});

  @override
  State<NightCastOverlay> createState() => _NightCastOverlayState();
}

class _NightCastOverlayState extends State<NightCastOverlay> with TickerProviderStateMixin {
  late final List<AnimationController> _moonControllers;
  late final List<_MoonSpec> _moonSpecs;
  late final AnimationController _starController;
  late final List<_StarSpec> _stars;

  static const _moonOpacity = [_Stop(0, 0), _Stop(0.08, 1), _Stop(0.80, 1), _Stop(0.96, 0), _Stop(1, 0)];
  static const _moonDx = [_Stop(0, 0), _Stop(0.30, -0.04), _Stop(0.55, 0.04), _Stop(0.80, -0.03), _Stop(1, 0)];
  static const _moonDy = [_Stop(0, -0.10), _Stop(0.30, 0.20), _Stop(0.55, 0.48), _Stop(0.80, 0.74), _Stop(1, 0.88)];

  @override
  void initState() {
    super.initState();
    _moonSpecs = const [
      _MoonSpec(duration: Duration(seconds: 14), phaseSeconds: 0, anchorX: 0.28, size: 62),
      _MoonSpec(duration: Duration(seconds: 17), phaseSeconds: 5, anchorX: 0.58, size: 48),
      _MoonSpec(duration: Duration(seconds: 12), phaseSeconds: 9, anchorX: 0.82, size: 40),
    ];
    _moonControllers = [
      for (final spec in _moonSpecs) AnimationController(vsync: this, duration: spec.duration)..repeat(),
    ];
    _starController = AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
    _stars = _buildStars();
  }

  @override
  void dispose() {
    for (final c in _moonControllers) {
      c.dispose();
    }
    _starController.dispose();
    super.dispose();
  }

  List<_StarSpec> _buildStars() {
    final rnd = math.Random(7);
    return [
      for (var i = 0; i < 16; i++)
        _StarSpec(
          baseX: 0.06 + rnd.nextDouble() * 0.88,
          baseY: 0.05 + rnd.nextDouble() * 0.65,
          ampX: 0.02 + rnd.nextDouble() * 0.05,
          ampY: 0.02 + rnd.nextDouble() * 0.05,
          freqX: 0.6 + rnd.nextDouble() * 1.6,
          freqY: 0.6 + rnd.nextDouble() * 1.6,
          phase: rnd.nextDouble() * math.pi * 2,
          size: i % 4 == 0 ? (10 + rnd.nextDouble() * 5) : (3 + rnd.nextDouble() * 3),
          sparkle: i % 4 == 0,
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
              AnimatedBuilder(
                animation: _starController,
                builder: (context, child) {
                  final t = _starController.value;
                  return CustomPaint(
                    size: Size(w, h),
                    painter: _StarfieldPainter(stars: _stars, t: t),
                  );
                },
              ),
              for (var i = 0; i < _moonSpecs.length; i++)
                AnimatedBuilder(
                  animation: _moonControllers[i],
                  builder: (context, child) {
                    final spec = _moonSpecs[i];
                    final periodSeconds = spec.duration.inMilliseconds / 1000;
                    final phaseFrac = (spec.phaseSeconds / periodSeconds) % 1.0;
                    final t = (_moonControllers[i].value + phaseFrac) % 1.0;

                    final opacity = _at(_moonOpacity, t).clamp(0.0, 1.0);
                    if (opacity <= 0.001) return const SizedBox.shrink();
                    final centerX = spec.anchorX * w + _at(_moonDx, t) * w;
                    final centerY = _at(_moonDy, t) * h;
                    final size = spec.size;
                    return Positioned(
                      left: centerX - size / 2,
                      top: centerY - size / 2,
                      width: size,
                      height: size,
                      child: Opacity(
                        opacity: opacity,
                        child: CustomPaint(painter: _MoonPainter(), size: Size(size, size)),
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

class _MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.saveLayer(Offset.zero & size, Paint());
    final glow = Paint()
      ..color = const Color(0xFFFDF3D0).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(r, r), r, glow);
    canvas.drawCircle(Offset(r, r), r * 0.82, Paint()..color = const Color(0xFFFDF3D0));
    canvas.drawCircle(
      Offset(r * 0.62, r * 0.72),
      r * 0.72,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarfieldPainter extends CustomPainter {
  final List<_StarSpec> stars;
  final double t;

  _StarfieldPainter({required this.stars, required this.t});

  Path _starPath(Offset c, double r) {
    final path = Path();
    const points = [
      Offset(0, -1), Offset(0.18, -0.18), Offset(1, 0), Offset(0.18, 0.18),
      Offset(0, 1), Offset(-0.18, 0.18), Offset(-1, 0), Offset(-0.18, -0.18),
    ];
    for (var i = 0; i < points.length; i++) {
      final p = c + Offset(points[i].dx * r, points[i].dy * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final x = (star.baseX + star.ampX * math.sin(2 * math.pi * (t * star.freqX) + star.phase)) * size.width;
      final y = (star.baseY + star.ampY * math.sin(2 * math.pi * (t * star.freqY) + star.phase * 1.3)) * size.height;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * (t * (star.freqX + star.freqY)) + star.phase));
      final paint = Paint()..color = const Color(0xFFFFF8DC).withValues(alpha: twinkle.clamp(0.0, 1.0));
      final c = Offset(x, y);
      if (star.sparkle) {
        canvas.drawPath(_starPath(c, star.size), paint);
      } else {
        canvas.drawCircle(c, star.size / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => true;
}
