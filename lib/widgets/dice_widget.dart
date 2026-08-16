import 'dart:async';

import 'package:flutter/material.dart';

import '../models/player_color.dart';

/// A classic pip-face die. While [rolling] is true it cycles rapidly
/// through random faces; once it turns false it settles on [value].
///
/// The body tints toward [color] (the current player's color) rather than
/// staying neutral white, so the die doubles as a "whose turn" cue.
class DiceWidget extends StatefulWidget {
  final int? value;
  final bool rolling;
  final double size;
  final PlayerColor color;

  const DiceWidget({
    super.key,
    required this.value,
    required this.rolling,
    required this.color,
    this.size = 56,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> {
  int _displayValue = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value ?? 1;
    if (widget.rolling) _startSpin();
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rolling && !oldWidget.rolling) {
      _startSpin();
    } else if (!widget.rolling && oldWidget.rolling) {
      _timer?.cancel();
      if (widget.value != null) setState(() => _displayValue = widget.value!);
    }
  }

  void _startSpin() {
    _timer?.cancel();
    // Cycles sequentially 1->6 (not a random flicker) so the roll reads as
    // countable even at speed -- three full loops before it's forced to
    // settle by the parent flipping `rolling` back to false. No click sound
    // here -- the bundled rattle clip (DiceRollSound, played by the parent)
    // is the only sound during a roll; layering the move-click on top of it
    // read as two competing/mixed sounds.
    var tick = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 28), (_) {
      setState(() => _displayValue = (tick % 6) + 1);
      tick++;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const Map<int, List<Alignment>> _pipLayouts = {
    1: [Alignment.center],
    2: [Alignment.topLeft, Alignment.bottomRight],
    3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
    4: [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight],
    5: [Alignment.topLeft, Alignment.topRight, Alignment.center, Alignment.bottomLeft, Alignment.bottomRight],
    6: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.centerRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
  };

  // Pastel body tint (top-left highlight) -> deeper body tint (bottom-right)
  // -> dark carved-pip color, all derived from the player's own color so the
  // bevel/gradient recipe stays identical across colors.
  static const Map<PlayerColor, Color> _tintLight = {
    PlayerColor.red: Color(0xFFFFE3E0),
    PlayerColor.green: Color(0xFFDFF6E7),
    PlayerColor.yellow: Color(0xFFFFF6D6),
    PlayerColor.blue: Color(0xFFDCF2FC),
  };
  static const Map<PlayerColor, Color> _tintDeep = {
    PlayerColor.red: Color(0xFFFF8177),
    PlayerColor.green: Color(0xFF7FD9A0),
    PlayerColor.yellow: Color(0xFFFFE082),
    PlayerColor.blue: Color(0xFF7FCBEE),
  };
  static const Map<PlayerColor, Color> _pipDark = {
    PlayerColor.red: Color(0xFF6B0F0A),
    PlayerColor.green: Color(0xFF0B4A22),
    PlayerColor.yellow: Color(0xFF6B5208),
    PlayerColor.blue: Color(0xFF063A56),
  };

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final pipSize = size * 0.16;
    final tintLight = _tintLight[widget.color]!;
    final tintDeep = _tintDeep[widget.color]!;
    final pipDark = _pipDark[widget.color]!;
    final pipMid = Color.lerp(pipDark, Colors.white, 0.3)!;

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: widget.rolling ? 1.08 : 1.0,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tintLight, tintDeep],
          ),
          borderRadius: BorderRadius.circular(size * 0.2),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.85),
              blurRadius: size * 0.12,
              blurStyle: BlurStyle.inner,
              offset: Offset(0, -size * 0.05),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: size * 0.12,
              blurStyle: BlurStyle.inner,
              offset: Offset(0, size * 0.06),
            ),
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: size * 0.1, offset: Offset(0, size * 0.04)),
          ],
        ),
        child: Stack(
          children: [
            for (final align in _pipLayouts[_displayValue] ?? const [])
              Align(
                alignment: align,
                child: Container(
                  width: pipSize,
                  height: pipSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      colors: [pipMid, pipDark],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: pipSize * 0.35, blurStyle: BlurStyle.inner),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
