import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../content/lang.dart';
import '../progress/profile.dart';

/// Text-to-speech using the device's built-in English/Vietnamese voices.
/// TODO: add speech recognition (speech_to_text) to check the child's spoken sentence.
class SpeechService {
  SpeechService({int Function()? speed}) : _speed = speed ?? (() => 1);

  /// Reading speed chosen by the parent: 0 = slow, 1 = a bit slow (default), 2 = normal.
  final int Function() _speed;
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// flutter_tts rate: on Android and iOS 0.5 = normal speed (Android's 1.0 is mapped to 0.5);
  /// on the web 1.0 = normal. Children hear it a little slower by default.
  double get _rate {
    const mobile = [0.33, 0.42, 0.5];
    const web = [0.7, 0.85, 1.0];
    final i = _speed().clamp(0, 2);
    return kIsWeb ? web[i] : mobile[i];
  }

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

final speechProvider = Provider<SpeechService>(
  (ref) => SpeechService(speed: () => ref.read(profileProvider).speechSpeed),
);
