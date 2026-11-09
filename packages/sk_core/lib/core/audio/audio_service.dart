import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/songs.dart';

/// Plays pre-generated marimba note samples (sk_core `assets/audio/notes/MIDI.wav`, MIDI 55..96).
class AudioService {
  AudioService() {
    for (var i = 0; i < 10; i++) {
      // Note samples are bundled inside the sk_core package.
      final p = AudioPlayer()..audioCache = AudioCache(prefix: '');
      p.setPlayerMode(PlayerMode.lowLatency).catchError((_) {});
      p.setReleaseMode(ReleaseMode.stop).catchError((_) {});
      _pool.add(p);
    }
  }

  final _pool = <AudioPlayer>[];
  var _next = 0;
  var _song = 0;
  var _pos = 0;
  final _songTimers = <Timer>[];

  void note(int midi, {double volume = 0.7}) {
    final m = midi.clamp(55, 96);
    final p = _pool[_next++ % _pool.length];
    () async {
      try {
        await p.stop();
        await p.play(
          AssetSource('packages/sk_core/assets/audio/notes/$m.wav'),
          volume: volume,
          mode: PlayerMode.lowLatency,
        );
      } catch (_) {
        /* audio is a nice-to-have; never crash the game */
      }
    }();
  }

  void _later(int ms, void Function() fn, {List<Timer>? into}) {
    final t = Timer(Duration(milliseconds: ms), fn);
    into?.add(t);
  }

  /// Each match plays the next note of the current level's song.
  void setSong(int i) {
    _song = i % parsedSongs.length;
    _pos = 0;
  }

  void matchNote({bool big = false, bool gentle = false}) {
    final s = parsedSongs[_song];
    final n = s[_pos % s.length];
    _pos++;
    note(n.midi, volume: gentle ? 0.35 : 0.75);
    if (big) _later(20, () => note(n.midi + 12, volume: 0.35));
  }

  void playSong(int i, {double beatSec = 0.34}) {
    stopSong();
    var t = 50.0;
    for (final n in parsedSongs[i % parsedSongs.length]) {
      _later(t.round(), () => note(n.midi, volume: 0.6), into: _songTimers);
      t += n.beats * beatSec * 1000;
    }
  }

  void stopSong() {
    for (final t in _songTimers) {
      t.cancel();
    }
    _songTimers.clear();
  }

  void winChime() {
    const ns = [72, 76, 79, 84];
    for (var i = 0; i < ns.length; i++) {
      _later(i * 120, () => note(ns[i], volume: 0.6));
    }
  }

  void soft() => note(55, volume: 0.3);

  /// Big happy chord for special blasts.
  void chord() {
    for (final m in const [60, 64, 67, 72]) {
      note(m, volume: 0.45);
    }
  }

  static const _penta = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24];
  void tap([int n = 0]) => note(67 + _penta[n % _penta.length], volume: 0.5);

  void sparkle() {
    const ns = [84, 88, 91, 96];
    for (var i = 0; i < ns.length; i++) {
      _later(i * 60, () => note(ns[i], volume: 0.3));
    }
  }
}

final audioProvider = Provider<AudioService>((ref) => AudioService());
