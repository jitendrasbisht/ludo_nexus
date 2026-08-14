import 'dart:typed_data';

/// Wraps mono 16-bit PCM [samples] in a minimal WAV container -- shared by
/// every synthesized in-app sound effect ([ClickSound], [DiceRollSound]).
Uint8List encodeMonoPcm16Wav(Int16List samples, int sampleRate) {
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
