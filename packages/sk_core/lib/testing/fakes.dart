/// Test doubles for the shared services (for widget tests in any app or game package).
library;

import '../core/audio/audio_service.dart';
import '../core/content/lang.dart';
import '../core/speech/speech_service.dart';

class FakeSpeech implements SpeechService {
  final said = <String>[];
  @override
  Future<void> speak(String text, Lang lang) async => said.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<bool> hasVoice(Lang lang) async => true;
}

class FakeAudio implements AudioService {
  @override
  void note(int midi, {double volume = 0.7}) {}
  @override
  void setSong(int i) {}
  @override
  void matchNote({bool big = false, bool gentle = false}) {}
  @override
  void playSong(int i, {double beatSec = 0.34}) {}
  @override
  void stopSong() {}
  @override
  void winChime() {}
  @override
  void soft() {}
  @override
  void tap([int n = 0]) {}
  @override
  void sparkle() {}
  @override
  void chord() {}
}
