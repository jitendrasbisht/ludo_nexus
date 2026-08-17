/// Global mute switch checked by [AudioPlayerPool] before every play() call
/// -- a single flag covers dice roll, move click, and capture sounds
/// since they all go through that shared pool.
class SoundSettings {
  static bool muted = false;
}
