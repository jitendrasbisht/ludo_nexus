import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Plays the bundled dice-intro clip once for the splash screen -- a real
/// audio asset (trimmed to its last 4 seconds), not synthesized.
///
/// Copies the asset to a local temp file up front and plays that via
/// [DeviceFileSource] rather than playing [AssetSource] directly -- see
/// [DiceRollSound] for why (AssetSource playback had a startup delay on
/// device that read as the clip being cut short).
class SplashJingleSound {
  static const durationMs = 4000;
  static const _assetPath = 'assets/sounds/splash_intro.mp3';

  static final AudioPlayer _player = AudioPlayer();
  static Future<void>? _preparing;
  static String? _filePath;

  static Future<void> _ensurePrepared() {
    return _preparing ??= _prepare();
  }

  static Future<void> _prepare() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ludo_splash_intro.mp3');
    if (!await file.exists()) {
      final bytes = await rootBundle.load(_assetPath);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    _filePath = file.path;
    await _player.setVolume(1.0);
    debugPrint('SplashJingleSound: source ready at ${file.path}');
  }

  static void preload() {
    _ensurePrepared();
  }

  static Future<void> play() async {
    try {
      await _ensurePrepared();
      await _player.stop();
      await _player.play(DeviceFileSource(_filePath!));
    } catch (e, st) {
      debugPrint('SplashJingleSound: play FAILED: $e\n$st');
      _preparing = null;
    }
  }
}
