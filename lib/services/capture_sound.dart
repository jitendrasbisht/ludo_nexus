import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Plays the bundled "magic burst" clip once when a move captures one or
/// more opponent pieces -- a real audio asset (not synthesized, unlike
/// [ClickSound]/[DiceRollSound]) since this one was supplied directly.
///
/// Copies the asset to a local temp file up front and plays that via
/// [DeviceFileSource] rather than playing [AssetSource] directly -- see
/// [DiceRollSound] for why (AssetSource playback had a startup delay on
/// device that read as the clip being cut short).
class CaptureSound {
  static const _assetPath = 'assets/sounds/capture_magic_burst.wav';

  static final AudioPlayer _player = AudioPlayer();
  static Future<void>? _preparing;
  static String? _filePath;

  static Future<void> _ensurePrepared() {
    return _preparing ??= _prepare();
  }

  static Future<void> _prepare() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ludo_capture_magic_burst.wav');
    if (!await file.exists()) {
      final bytes = await rootBundle.load(_assetPath);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    _filePath = file.path;
    await _player.setVolume(1.0);
    debugPrint('CaptureSound: source ready at ${file.path}');
  }

  /// Call as soon as a game screen opens so the first capture doesn't pay
  /// the one-time copy/decode cost.
  static void preload() {
    _ensurePrepared();
  }

  static Future<void> play() async {
    try {
      await _ensurePrepared();
      await _player.stop();
      await _player.play(DeviceFileSource(_filePath!));
    } catch (e, st) {
      debugPrint('CaptureSound: play FAILED: $e\n$st');
      _preparing = null; // allow a retry on the next play()
    }
  }
}
