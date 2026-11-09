import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../content/lang.dart';

/// Text-to-speech using the device's built-in English/Vietnamese voices.
/// TODO: add speech recognition (speech_to_text) to check the child's spoken sentence.
class SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  // Speech-rate scales differ by platform: iOS 0.5 ≈ normal; Android/web 1.0 ≈ normal.
  double get _rate => _isIOS ? 0.45 : 0.8;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.awaitSpeakCompletion(false);
      if (_isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      }
    } catch (_) {}
  }

  Future<void> speak(String text, Lang lang) async {
    await _init();
    try {
      await _tts.stop();
      await _tts.setLanguage(lang.ttsCode);
      await _tts.setSpeechRate(_rate);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<bool> hasVoice(Lang lang) async {
    await _init();
    try {
      final r = await _tts.isLanguageAvailable(lang.ttsCode);
      return r == true || r == 1;
    } catch (_) {
      return false;
    }
  }
}

final speechProvider = Provider<SpeechService>((ref) => SpeechService());
