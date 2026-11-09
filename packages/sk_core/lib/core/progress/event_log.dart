import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

String dayKey([DateTime? d]) =>
    DateFormat('yyyy-MM-dd').format(d ?? DateTime.now());

class GameEvent {
  GameEvent(this.t, this.type, this.game, this.data);
  final int t; // epoch ms
  final String type;
  final String? game;
  final Map<String, dynamic> data;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(t);
  T? get<T>(String k) => data[k] as T?;

  Map<String, Object?> toJson() => {
    't': t,
    'type': type,
    if (game != null) 'game': game,
    'd': data,
  };
  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
    j['t'] as int,
    j['type'] as String,
    j['game'] as String?,
    (j['d'] as Map?)?.cast<String, dynamic>() ?? {},
  );
}

/// Append-only learning event log (on-device only).
/// Event types used today: start, level_start, level, quit, sentence, music, calm, break, lang, app_open.
/// TODO(production): move to SQLite once logs grow or cloud sync is added.
class EventLog {
  EventLog(this._prefs) : _key = 'events.default' {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        events.addAll(
          (jsonDecode(raw) as List).map(
            (e) => GameEvent.fromJson(e as Map<String, dynamic>),
          ),
        );
      } catch (_) {
        /* corrupted log: start fresh */
      }
    }
  }

  final String _key;
  static const _max = 5000;
  final SharedPreferences _prefs;
  final List<GameEvent> events = [];

  void log(String type, {String? game, Map<String, dynamic> data = const {}}) {
    events.add(
      GameEvent(DateTime.now().millisecondsSinceEpoch, type, game, data),
    );
    if (events.length > _max) events.removeRange(0, events.length - _max);
    _prefs.setString(_key, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  /// Replace the log (used for demo data in QA builds).
  void replaceAll(List<GameEvent> all) {
    events
      ..clear()
      ..addAll(all);
    _prefs.setString(_key, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  Iterable<GameEvent> ofType(String type) =>
      events.where((e) => e.type == type);

  Future<void> clear() async {
    events.clear();
    await _prefs.remove(_key);
  }
}

final eventLogProvider = Provider<EventLog>(
  (ref) => EventLog(ref.read(prefsProvider)),
);
