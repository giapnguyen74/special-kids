import 'dart:math';

import '../core/progress/event_log.dart';
import '../core/progress/profile.dart';

/// QA / demo only (--dart-define=SK_DEMO=true): two weeks of a child who is slowly improving,
/// was stuck on one level for a while and rarely speaks aloud yet.
void seedDemoData(EventLog log, ProfileNotifier profile) {
  final rng = Random(5);
  final now = DateTime.now();
  final out = <GameEvent>[];
  var levelIdx = 0;
  for (var d = 13; d >= 0; d--) {
    if (d % 4 == 3) continue; // some days off
    final day = DateTime(
      now.year,
      now.month,
      now.day,
      17,
    ).subtract(Duration(days: d));
    var t = day.millisecondsSinceEpoch;
    void add(String type, Map<String, dynamic> data) {
      t += 20000 + rng.nextInt(60000);
      out.add(GameEvent(t, type, 'snack_beats', data));
    }

    final progress = (13 - d) / 13; // 0 -> 1 over two weeks
    add('app_open', {});
    for (var k = 0; k < 4; k++) {
      final self = rng.nextDouble() < 0.15 + 0.55 * progress;
      add('start', {
        'context': 'level',
        'latency': self ? 1800 : 7000 + rng.nextInt(6000),
        'selfStart': self,
        'hand': !self && rng.nextBool(),
      });
      add('level_start', {'level': levelIdx});
      final stuck = levelIdx == 12 && d > 4;
      final win = !stuck && rng.nextDouble() < 0.55 + 0.35 * progress;
      if (!win && rng.nextDouble() < 0.3) {
        add('quit', {'level': levelIdx});
        continue;
      }
      add('level', {'level': levelIdx, 'result': win ? 'win' : 'retry'});
      if (win) {
        final wrong = max(
          0,
          (2.5 - 2.5 * progress + rng.nextDouble() - 0.5).round(),
        );
        add('sentence', {
          'lang': 'vi',
          'words': 3 + (levelIdx % 5),
          'wrong': wrong,
          'hints': wrong > 1 ? 1 : 0,
          'spoke': rng.nextDouble() < 0.1 + 0.2 * progress,
          'food': [4, 0, 4, 3][rng.nextInt(4)],
          'choiceMs': (9000 - 5000 * progress + rng.nextInt(2000)).round(),
        });
        levelIdx++;
      }
    }
    if (rng.nextBool()) {
      add('music', {
        'song': [0, 3, 3, 6][rng.nextInt(4)],
      });
    }
    if (d % 5 == 0) add('calm', {});
    profile.update(
      (p) => p.playMs[dayKey(day)] = (6 + rng.nextInt(14)) * 60000,
    );
  }
  log.replaceAll(out);
  profile.update((p) {
    p.gameLevels['snack_beats'] = levelIdx;
    p.stars = 120;
    p.songs = [0, 1, 2, 3, 4];
    p.hintLevel['vi'] = 1;
  });
}
