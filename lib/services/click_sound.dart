import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A short synthesized "click" tone used as a placeholder move-sound until
/// real audio assets are available. Generated in-memory as raw PCM/WAV so
/// no bundled audio asset is needed.
///
/// Deliberately uses the default MediaPlayer-backed player mode, not
/// [PlayerMode.lowLatency] (SoundPool). On at least one real device tested
/// (a heavily customized OEM Android skin), SoundPool produced no audible
/// output at all -- for either this app's own SoundPool-backed playback or
/// even the OS's own SystemSound.click (which is itself SoundPool-backed
/// under the hood) -- while plain MediaPlayer worked correctly. SoundPool
/// would have been faster, but working audio beats a faster silent one.
class ClickSound {
  static final AudioPlayer _player = AudioPlayer();
  static Future<void>? _preparing;
  static String? _filePath;

  static Future<void> _ensurePrepared() {
    return _preparing ??= _prepare();
  }

  static Future<void> _prepare() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ludo_click.wav');
    if (!await file.exists()) {
      await file.writeAsBytes(_generateClickWav(), flush: true);
    }
    _filePath = file.path;
    await _player.setVolume(1.0);
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
      // Once a MediaPlayer-backed clip finishes it moves to
      // PlayerState.completed, and resume() alone doesn't reliably restart
      // it from there (this is why only the very first click worked).
      // Calling play(source) fresh each time forces a real restart.
      await _player.stop();
      await _player.play(DeviceFileSource(_filePath!));
    } catch (e, st) {
      debugPrint('ClickSound: play FAILED: $e\n$st');
      _preparing = null; // allow a retry on the next play()
    }
  }

  static Uint8List _generateClickWav() {
    const sampleRate = 44100;
    const durationMs = 150;
    const bodyFreq = 320.0; // low "thock" for perceived punch/loudness
    const clickFreq = 1500.0; // higher transient for a crisp "click" edge
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(sampleCount);

    // Fast attack, a genuine sustain plateau at full volume, then decay --
    // a linear-decay-only envelope (the original approach) puts most of
    // the energy right at the very start, which reads as quiet/thin.
    final attackSamples = (sampleCount * 0.04).round().clamp(1, sampleCount);
    final sustainSamples = (sampleCount * 0.35).round();

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      double envelope;
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i < attackSamples + sustainSamples) {
        envelope = 1.0;
      } else {
        final decayIndex = i - attackSamples - sustainSamples;
        final decayLength = sampleCount - attackSamples - sustainSamples;
        envelope = 1.0 - (decayIndex / decayLength);
      }

      final body = sin(2 * pi * bodyFreq * t) * 0.6;
      final click = sin(2 * pi * clickFreq * t) * 0.4;
      final mixed = (body + click) * envelope;
      samples[i] = (mixed * 32000).clamp(-32000, 32000).round();
    }

    return _wavBytes(samples, sampleRate);
  }

  static Uint8List _wavBytes(Int16List samples, int sampleRate) {
    final dataLength = samples.length * 2;
    final buffer = BytesBuilder();

    void writeString(String s) => buffer.add(s.codeUnits);
    void writeUint32(int v) => buffer.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void writeUint16(int v) => buffer.add([v & 0xff, (v >> 8) & 0xff]);

    writeString('RIFF');
    writeUint32(36 + dataLength);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(1); // mono
    writeUint32(sampleRate);
    writeUint32(sampleRate * 2); // byte rate
    writeUint16(2); // block align
    writeUint16(16); // bits per sample
    writeString('data');
    writeUint32(dataLength);
    for (final s in samples) {
      writeUint16(s & 0xffff);
    }

    return buffer.toBytes();
  }
}
