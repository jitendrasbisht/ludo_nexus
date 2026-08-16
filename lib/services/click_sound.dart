import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_player_pool.dart';
import 'wav_encoder.dart';

/// A short synthesized "bouncy pop" (a quick downward pitch sweep) played
/// once per cell as a piece walks across the board. Generated in-memory as
/// raw PCM/WAV so no bundled audio asset is needed.
///
/// Deliberately uses the default MediaPlayer-backed player mode, not
/// [PlayerMode.lowLatency] (SoundPool). On at least one real device tested
/// (a heavily customized OEM Android skin), SoundPool produced no audible
/// output at all -- for either this app's own SoundPool-backed playback or
/// even the OS's own SystemSound.click (which is itself SoundPool-backed
/// under the hood) -- while plain MediaPlayer worked correctly. SoundPool
/// would have been faster, but working audio beats a faster silent one.
class ClickSound {
  static final AudioPlayerPool _pool = AudioPlayerPool();
  static Future<void>? _preparing;
  static String? _filePath;

  static Future<void> _ensurePrepared() {
    return _preparing ??= _prepare();
  }

  static Future<void> _prepare() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ludo_move_pop.wav');
    if (!await file.exists()) {
      await file.writeAsBytes(_generateClickWav(), flush: true);
    }
    _filePath = file.path;
    await _pool.setVolume(1.0);
    debugPrint('ClickSound: source ready at ${file.path}');
  }

  /// Call as soon as a game screen opens so the one-time decode/load cost
  /// happens before the player's first move, not during it.
  static void preload() {
    _ensurePrepared();
  }

  static Future<void> play() async {
    try {
      await _ensurePrepared();
      await _pool.play(_filePath!);
    } catch (e, st) {
      debugPrint('ClickSound: play FAILED: $e\n$st');
      _preparing = null; // allow a retry on the next play()
    }
  }

  static Uint8List _generateClickWav() {
    const sampleRate = 44100;
    const durationMs = 100;
    const freqStart = 900.0;
    const freqEnd = 220.0;
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(sampleCount);

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final progress = i / sampleCount;
      final freq = freqStart + (freqEnd - freqStart) * progress;
      final attack = t > 0.003 ? 1.0 : t / 0.003;
      final envelope = exp(-t * 22) * attack;
      final mixed = sin(2 * pi * freq * t) * envelope;
      samples[i] = (mixed * 32000).clamp(-32000, 32000).round();
    }

    return encodeMonoPcm16Wav(samples, sampleRate);
  }
}
