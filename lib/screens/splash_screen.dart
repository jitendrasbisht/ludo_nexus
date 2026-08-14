import 'dart:math';

import 'package:flutter/material.dart';

import '../models/player_color.dart';
import '../services/splash_jingle_sound.dart';
import '../widgets/app_background.dart';
import '../widgets/ludo_colors.dart';
import 'setup_screen.dart';

/// The first thing players see on launch: the app's own 4 player colors,
/// each as a bigger die arranged in a 2x2 square, tumbling in from the
/// sides and spinning to a stop, then a confetti burst pops behind them as
/// the app name fades up. Plays the bundled dice-intro clip alongside it,
/// then swaps itself out for [SetupScreen] once both finish, 4s later.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _totalDuration = Duration(milliseconds: SplashJingleSound.durationMs);

  late final AnimationController _tumbleController;
  late final AnimationController _confettiController;
  late final AnimationController _brandController;

  static const _dice = [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue];

  final List<_ConfettiBit> _confetti = _generateConfetti();

  @override
  void initState() {
    super.initState();

    _tumbleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    _brandController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

    // AnimationController.forward() starts counting real wall-clock time
    // immediately -- but on a cold start, several seconds can pass between
    // initState() running and the engine actually presenting its first
    // frame (asset decoding, shader compilation). Starting the timeline
    // here meant the whole tumble animation played out silently during
    // that invisible window, so by the time anything was actually on
    // screen the dice were already sitting in their final position with
    // no visible motion at all. Waiting for the first real frame first
    // means the animation (and the sound, kept in sync with it) only
    // starts once there's something on screen to show it against.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Even after the first frame callback fires, the very first frame
      // that actually includes shadows/transforms (as used here) can
      // still stall the UI thread for a beat while Impeller compiles
      // those shader variants for the first time ever -- a short buffer
      // here lets that settle before the timed animation starts, so it
      // doesn't get silently eaten by that stall too.
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      SplashJingleSound.play();
      _tumbleController.forward();

      Future.delayed(const Duration(milliseconds: 1050), () {
        if (!mounted) return;
        _confettiController.forward();
        _brandController.forward();
      });

      Future.delayed(_totalDuration, () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SetupScreen()));
      });
    });
  }

  @override
  void dispose() {
    _tumbleController.dispose();
    _confettiController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 340,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    // The dice tumble in from +-140px either side of this
                    // 340-wide box, and confetti bursts out to ~160px --
                    // both would get cut off by Stack's default hard-edge
                    // clip while still mid-flight, reading as an instant
                    // pop-in instead of a visible entrance.
                    clipBehavior: Clip.none,
                    children: [
                      // Positioned off-screen but still genuinely painted
                      // every frame from the very first build -- this is
                      // the same BoxShadow + Transform combination the
                      // real animated dice use, and it's the *first ever
                      // paint* of that combination that stalls the UI
                      // thread while Impeller compiles those shader
                      // variants (not when the animation itself starts).
                      // Forcing that stall here, off-screen, during the
                      // few seconds the splash is already invisible during
                      // cold start, means it's already paid for by the
                      // time the real entrance animation needs to run, so
                      // that one doesn't stall and silently skip ahead.
                      Positioned(
                        left: -1000,
                        top: -1000,
                        child: Transform.scale(
                          scale: 1.0,
                          child: Transform.rotate(
                            angle: 0.001,
                            child: _SplashDie(color: _dice[0].material, pip: 1),
                          ),
                        ),
                      ),
                      // 2x2 square arrangement -- the top row tumbles in from
                      // the left, the bottom row from the right, so the
                      // dice can be bigger than a single row would allow.
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTumblingDie(0, fromLeft: true),
                              const SizedBox(width: 14),
                              _buildTumblingDie(1, fromLeft: false),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTumblingDie(2, fromLeft: true),
                              const SizedBox(width: 14),
                              _buildTumblingDie(3, fromLeft: false),
                            ],
                          ),
                        ],
                      ),
                      // Painted after (on top of) the dice, and only once
                      // they've landed, so the burst is actually visible
                      // instead of hidden behind the solid-colored tiles.
                      IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _confettiController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                for (final bit in _confetti) _buildConfettiBit(bit, _confettiController.value),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _brandController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _brandController.value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - _brandController.value) * 12),
                        child: child,
                      ),
                    );
                  },
                  child: const Text(
                    'Ludo Nexus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTumblingDie(int i, {required bool fromLeft}) {
    return AnimatedBuilder(
      animation: _tumbleController,
      builder: (context, child) {
        final delay = i * 0.1;
        final raw = ((_tumbleController.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(raw);
        final startX = fromLeft ? -140.0 : 140.0;
        final dx = startX * (1 - eased);
        final rotations = fromLeft ? 3.2 : -3.2;
        // Zooms in from small to full size at the same time as the
        // fly-in/spin, so it reads as a punchy "zoom + tumble" landing
        // rather than a same-size die just sliding sideways.
        final scale = 0.25 + 0.75 * eased;
        return Opacity(
          opacity: raw == 0 ? 0 : 1,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.rotate(
              angle: rotations * (1 - eased),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: _SplashDie(color: _dice[i].material, pip: i + 1),
    );
  }

  Widget _buildConfettiBit(_ConfettiBit bit, double t) {
    if (t <= 0) return const SizedBox.shrink();
    final eased = Curves.easeOut.transform(t);
    final dx = cos(bit.angle) * bit.distance * eased;
    final dy = sin(bit.angle) * bit.distance * eased;
    final opacity = (1 - t).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: bit.angle * 3 * t,
          child: Container(
            width: bit.size,
            height: bit.size,
            decoration: BoxDecoration(color: bit.color, borderRadius: BorderRadius.circular(1.5)),
          ),
        ),
      ),
    );
  }

  static List<_ConfettiBit> _generateConfetti() {
    final random = Random(7);
    final colors = [for (final c in PlayerColor.values) c.material];
    return List.generate(28, (i) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = 90 + random.nextDouble() * 70;
      final size = 4.0 + random.nextDouble() * 4;
      final color = colors[i % colors.length];
      return _ConfettiBit(angle: angle, distance: distance, size: size, color: color);
    });
  }
}

class _ConfettiBit {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  const _ConfettiBit({required this.angle, required this.distance, required this.size, required this.color});
}

class _SplashDie extends StatelessWidget {
  final Color color;
  final int pip;

  const _SplashDie({required this.color, required this.pip});

  static const Map<int, List<Alignment>> _pipLayouts = {
    1: [Alignment.center],
    2: [Alignment.topLeft, Alignment.bottomRight],
    3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
    4: [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight],
  };

  @override
  Widget build(BuildContext context) {
    const size = 104.0;
    final onDie = color == const Color(0xFFFFFF00) ? Colors.black87 : Colors.white;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: size * 0.14, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          for (final align in _pipLayouts[pip] ?? const [])
            Align(
              alignment: align,
              child: Container(
                width: size * 0.16,
                height: size * 0.16,
                decoration: BoxDecoration(color: onDie, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}
