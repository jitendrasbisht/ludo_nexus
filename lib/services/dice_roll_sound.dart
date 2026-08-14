import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Plays the bundled "metal box" dice-rattle clip once for the whole
/// dice-roll spin -- a real audio asset (not synthesized, unlike
/// [ClickSound]) since this one was supplied directly.
///
/// Copies the asset to a local temp file up front and plays that via
/// [DeviceFileSource] rather than playing [AssetSource] directly: on
/// device, AssetSource playback had a startup delay (the plugin copies
/// the asset out of the bundle on every play call) that ran past our
/// fixed-duration wait, so the code moved on to the next phase before the
/// clip's tail had actually played -- reading as the sound getting cut
/// off. This is the same reliable pattern already used by [ClickSound].
class DiceRollSound {
  static const durationMs = 1000;
  static const _assetPath = 'assets/sounds/dice_roll_metal_box.wav';

  static final AudioPlayer _player = AudioPlayer();
  static Future<void>? _preparing;
  static String? _filePath;

  static Future<void> _ensurePrepared() {
    return _preparing ??= _prepare();
  }

  static Future<void> _prepare() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ludo_dice_roll_metal_box.wav');
    if (!await file.exists()) {
      final bytes = await rootBundle.load(_assetPath);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    _filePath = file.path;
    await _player.setVolume(1.0);
    debugPrint('DiceRollSound: source ready at ${file.path}');
  }

  /// Call as soon as a game screen opens so the first roll doesn't pay
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
      debugPrint('DiceRollSound: play FAILED: $e\n$st');
      _preparing = null; // allow a retry on the next play()
    }
  }
}
