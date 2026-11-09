import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

/// Microphone LOUDNESS meter (0..1). Used to reward the child for using their voice.
///
/// Privacy: audio is never stored or sent anywhere — the raw stream is discarded
/// and only the loudness level is read.
/// TODO: add speech recognition later to check the actual words.
class VoiceMeter {
  AudioRecorder? _rec;
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<dynamic>? _dataSub;
  final _levels = StreamController<double>.broadcast();
  bool active = false;

  Stream<double> get levels => _levels.stream;

  /// Starts listening. Returns false if there is no mic or permission was denied.
  Future<bool> start() async {
    if (active) return true;
    // On the web build the recorder plugin freezes the page's main thread for ~20 s at a time
    // (measured), so the web version uses the "I sang / I said it" buttons instead.
    if (kIsWeb) return false;
    try {
      final rec = _rec ??= AudioRecorder();
      if (!await rec.hasPermission()) return false;
      final stream = await rec.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
          echoCancel: true, // reduce the app's own music being heard as "voice"
          noiseSuppress: true,
          iosConfig: IosRecordConfig(
            categoryOptions: [
              IosAudioCategoryOption.defaultToSpeaker,
              IosAudioCategoryOption.mixWithOthers,
              IosAudioCategoryOption.allowBluetooth,
              IosAudioCategoryOption.allowBluetoothA2DP,
            ],
          ),
        ),
      );
      _dataSub = stream.listen((_) {}); // discard audio data
      _ampSub = rec
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) {
            // dBFS (-60 quiet .. -10 loud) -> 0..1
            _levels.add(((a.current + 60) / 50).clamp(0.0, 1.0));
          });
      active = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    await _ampSub?.cancel();
    await _dataSub?.cancel();
    _ampSub = null;
    _dataSub = null;
    if (active) {
      try {
        await _rec?.stop();
      } catch (_) {}
    }
    active = false;
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
  }
}

final voiceProvider = Provider<VoiceMeter>((ref) {
  final v = VoiceMeter();
  ref.onDispose(v.dispose);
  return v;
});
