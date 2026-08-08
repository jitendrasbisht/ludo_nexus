import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/click_sound.dart';

/// A classic pip-face die. While [rolling] is true it cycles rapidly
/// through random faces; once it turns false it settles on [value].
class DiceWidget extends StatefulWidget {
  final int? value;
  final bool rolling;
  final double size;

  const DiceWidget({super.key, required this.value, required this.rolling, this.size = 56});

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> {
  int _displayValue = 1;
  Timer? _timer;
  final _random = Random();

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
    // The face cycles fast for a visible rattle, but the click sound only
    // fires every other tick -- rapid-fire stop()+play() calls faster than
    // ~150ms apart aren't reliable on a MediaPlayer-backed player.
    var tick = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      setState(() => _displayValue = _random.nextInt(6) + 1);
      tick++;
      if (tick.isEven) ClickSound.play();
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

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final pipSize = size * 0.16;
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: widget.rolling ? 1.08 : 1.0,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: size * 0.1, offset: Offset(0, size * 0.03)),
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
                  decoration: const BoxDecoration(color: Color(0xFF222222), shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
