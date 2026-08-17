import 'package:audioplayers/audioplayers.dart';

import 'sound_settings.dart';

/// A small pool of alternating [AudioPlayer]s, used instead of a single
/// player doing stop()-then-play() on every call.
///
/// Rapid back-to-back stop()+play() on ONE MediaPlayer-backed player isn't
/// reliable on some devices -- testers on Xiaomi/MIUI, iQOO, and Samsung
/// phones all reported the same symptom (sound missing or mixing/garbled).
/// The previous clip's stop doesn't always finish settling natively before
/// the next play() call starts, so the new clip either gets dropped or
/// overlaps with the tail of the one still winding down. Rotating across a
/// few players means each individual player gets far more real time
/// between its own stop/play cycles, which avoids that race without
/// needing [PlayerMode.lowLatency] (SoundPool) -- already ruled out
/// elsewhere in this codebase for producing no audio at all on at least
/// one real device.
class AudioPlayerPool {
  final List<AudioPlayer> _players;
  int _next = 0;

  AudioPlayerPool({int size = 3}) : _players = List.generate(size, (_) => AudioPlayer());

  Future<void> setVolume(double volume) async {
    for (final player in _players) {
      await player.setVolume(volume);
    }
  }

  Future<void> play(String filePath) async {
    if (SoundSettings.muted) return;
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    await player.stop();
    await player.play(DeviceFileSource(filePath));
  }
}
