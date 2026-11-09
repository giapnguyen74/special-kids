// Generates soft marimba-like note samples (MIDI 55..96) as 16-bit mono WAV files.
// Run: dart run tool/gen_notes.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 22050;
  const seconds = 1.2;
  final n = (sampleRate * seconds).round();
  final dir = Directory('assets/audio/notes')..createSync(recursive: true);
  for (var midi = 55; midi <= 96; midi++) {
    final f = 440 * pow(2, (midi - 69) / 12);
    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final attack = min(1.0, t / 0.008);
      final env = attack * exp(-t * 4.2);
      final v =
          sin(2 * pi * f * t) + 0.12 * sin(2 * pi * f * 4 * t) * exp(-t * 9);
      pcm[i] = (v * env * 0.55 * 32767).round().clamp(-32768, 32767);
    }
    File('${dir.path}/$midi.wav').writeAsBytesSync(_wav(pcm, sampleRate));
  }
  stdout.writeln('wrote ${96 - 55 + 1} notes to ${dir.path}');
}

Uint8List _wav(Int16List pcm, int rate) {
  final data = pcm.buffer.asUint8List();
  final b = BytesBuilder();
  void str(String s) => b.add(s.codeUnits);
  void u32(int v) =>
      b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
  str('RIFF');
  u32(36 + data.length);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(data.length);
  b.add(data);
  return b.toBytes();
}
