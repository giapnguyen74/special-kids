import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../progress/event_log.dart';
import '../progress/profile.dart';

/// Counts active play time (only while a game screen is open and the app is in the foreground).
/// Used for the parent dashboard and the gentle "time for a break" screen.
class SessionTracker with WidgetsBindingObserver {
  SessionTracker(this._ref) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  final Ref _ref;
  late final Timer _timer;
  int sessionPlayMs = 0;
  int _active = 0;
  bool _foreground = true;

  void enter() => _active++;
  void leave() => _active = (_active - 1).clamp(0, 1 << 30);

  bool get breakDue {
    final limit = _ref.read(profileProvider).sessionLimitMin;
    return limit > 0 && sessionPlayMs >= limit * 60000;
  }

  void resetSession() => sessionPlayMs = 0;

  void _tick() {
    if (_active == 0 || !_foreground) return;
    sessionPlayMs += 5000;
    final k = dayKey();
    _ref
        .read(profileProvider.notifier)
        .update((p) => p.playMs[k] = (p.playMs[k] ?? 0) + 5000);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

final sessionProvider = Provider<SessionTracker>((ref) {
  final s = SessionTracker(ref);
  ref.onDispose(s.dispose);
  return s;
});

/// Mixin for game screens: counts play time while the screen is mounted.
mixin TracksPlayTime<T extends StatefulWidget> on State<T> {
  SessionTracker? _tracker;

  void startTracking(SessionTracker tracker) {
    _tracker = tracker..enter();
  }

  @override
  void dispose() {
    _tracker?.leave();
    super.dispose();
  }
}
