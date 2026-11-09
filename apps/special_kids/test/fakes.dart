import 'dart:async';

export 'package:sk_core/testing/fakes.dart';

import 'package:special_kids/voice/voice_meter.dart';

/// Fake microphone: emits [level] every 100 ms while active.
class FakeVoice implements VoiceMeter {
  FakeVoice({this.available = true});
  final bool available;
  double level = 0.1;
  Timer? _timer;
  final _c = StreamController<double>.broadcast();

  @override
  bool active = false;

  @override
  Stream<double> get levels => _c.stream;

  @override
  Future<bool> start() async {
    if (!available) return false;
    active = true;
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _c.add(level),
    );
    return true;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    active = false;
  }

  @override
  Future<void> dispose() => stop();
}
