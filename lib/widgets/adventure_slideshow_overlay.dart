import 'dart:async';

import 'package:flutter/material.dart';

/// Decorative animated background for the Adventure theme: a crossfading
/// slideshow of real photos (no vector/CSS-style "fake nature motion" to
/// get wrong) with a slow Ken Burns drift on each one. Purely decorative
/// -- ignores pointer events so it never blocks taps.
class AdventureSlideshowOverlay extends StatefulWidget {
  const AdventureSlideshowOverlay({super.key});

  static const List<String> _photos = [
    'assets/background/adventure/DSCN1227.jpg',
    'assets/background/adventure/DSCN1102.jpg',
    'assets/background/adventure/DSCN1215.jpg',
    'assets/background/adventure/DSCN1103.jpg',
    'assets/background/adventure/DSCN1202.jpg',
    'assets/background/adventure/DSCN1116.jpg',
    'assets/background/adventure/IMG_0603.jpg',
    'assets/background/adventure/DSCN1198.jpg',
    'assets/background/adventure/DSCN1216.jpg',
    'assets/background/adventure/DSCN1105.jpg',
    'assets/background/adventure/DSCN1221.jpg',
    'assets/background/adventure/DSCN1192.jpg',
  ];

  static const Duration _slideDuration = Duration(milliseconds: 3400);
  static const Duration _crossfadeDuration = Duration(milliseconds: 900);

  @override
  State<AdventureSlideshowOverlay> createState() => _AdventureSlideshowOverlayState();
}

class _AdventureSlideshowOverlayState extends State<AdventureSlideshowOverlay> {
  int _index = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(AdventureSlideshowOverlay._slideDuration, (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % AdventureSlideshowOverlay._photos.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black,
        child: AnimatedSwitcher(
          duration: AdventureSlideshowOverlay._crossfadeDuration,
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          child: _KenBurnsPhoto(
            key: ValueKey(_index),
            assetPath: AdventureSlideshowOverlay._photos[_index],
            duration: AdventureSlideshowOverlay._slideDuration,
          ),
        ),
      ),
    );
  }
}

/// A single photo that slowly zooms in for the duration it's on screen --
/// restarts fresh each time it's re-keyed by a new index in the slideshow.
class _KenBurnsPhoto extends StatefulWidget {
  final String assetPath;
  final Duration duration;

  const _KenBurnsPhoto({super.key, required this.assetPath, required this.duration});

  @override
  State<_KenBurnsPhoto> createState() => _KenBurnsPhotoState();
}

class _KenBurnsPhotoState extends State<_KenBurnsPhoto> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..forward();
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
      child: Image.asset(
        widget.assetPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}
