import 'package:flutter_test/flutter_test.dart';
import 'package:sk_core/core/content/lang.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/parents/insights.dart';

final now = DateTime(2026, 11, 10, 18);
int _t = 0;
GameEvent ev(String type, Map<String, dynamic> d, {int daysAgo = 0}) =>
    GameEvent(
      now
          .subtract(Duration(days: daysAgo, minutes: 500 - (_t++)))
          .millisecondsSinceEpoch,
      type,
      'snack_beats',
      d,
    );

void main() {
  test('new child: no data, no false alarms', () {
    final ins = computeInsights([], ChildProfile(), Lang.en, now: now);
    expect(ins.enoughData, isFalse);
    expect(ins.difficulties, isEmpty);
    expect(ins.engagement.interest, Interest.noData);
    expect(ins.skills.every((s) => s.level == SkillLevel.noData), isTrue);
  });

  test('improving child: skills trend up, highlights, interested', () {
    final events = <GameEvent>[
      // starts: first needed cues, later starts alone
      for (var i = 0; i < 10; i++)
        ev('start', {'latency': 6000, 'selfStart': false}, daysAgo: 6 - i ~/ 2),
      for (var i = 0; i < 10; i++)
        ev('start', {'latency': 1500, 'selfStart': true}, daysAgo: 1),
      // sentences: first with mistakes, later perfect
      for (var i = 0; i < 6; i++)
        ev('sentence', {
          'words': 4,
          'wrong': 2,
          'hints': 1,
          'spoke': false,
          'food': 1,
          'choiceMs': 9000,
        }, daysAgo: 5),
      for (var i = 0; i < 6; i++)
        ev('sentence', {
          'words': 6,
          'wrong': 0,
          'hints': 0,
          'spoke': true,
          'food': 1,
          'choiceMs': 3000,
        }, daysAgo: 1),
      for (var i = 0; i < 8; i++) ...[
        ev('level_start', {'level': i}, daysAgo: i % 7),
        ev('level', {'level': i, 'result': 'win'}, daysAgo: i % 7),
      ],
      for (var d = 0; d < 6; d++) ev('app_open', {}, daysAgo: d),
    ];
    final p = ChildProfile(
      hintLevel: {'en': 2, 'vi': 0},
      gameLevels: {'snack_beats': 8},
    );
    for (var d = 0; d < 6; d++) {
      p.playMs[dayKey(now.subtract(Duration(days: d)))] = 12 * 60000;
    }
    final ins = computeInsights(events, p, Lang.en, now: now);
    final byId = {for (final s in ins.skills) s.id: s};
    expect(byId['initiation']!.trend, Trend.up);
    expect(byId['sentences']!.trend, Trend.up);
    expect(byId['speaking']!.trend, Trend.up);
    expect(byId['choices']!.trend, Trend.up); // faster decisions
    expect(byId['focus']!.level, SkillLevel.strong);
    expect(ins.engagement.interest, Interest.veryInterested);
    expect(
      ins.engagement.favorites.map((f) => f.$2),
      contains(contains('green apple')),
    );
    expect(ins.highlights, contains('Builds sentences with no hints now 🧩'));
    expect(
      ins.difficulties.where((d) => d.severity == Severity.important),
      isEmpty,
    );
  });

  test('struggling child: stuck level, needs cues, quits — each with a tip (Vietnamese)', () {
    final events = <GameEvent>[
      for (var i = 0; i < 8; i++)
        ev('start', {'latency': 14000, 'selfStart': false, 'hand': true}),
      for (var i = 0; i < 5; i++) ev('level_start', {'level': 12}),
      for (var i = 0; i < 4; i++) ev('level', {'level': 12, 'result': 'retry'}),
      for (var i = 0; i < 3; i++) ev('quit', {'level': 12}),
      for (var i = 0; i < 6; i++)
        ev('sentence', {
          'words': 5,
          'wrong': 3,
          'hints': 2,
          'spoke': false,
          'food': 0,
        }),
    ];
    final ins = computeInsights(events, ChildProfile(), Lang.vi, now: now);
    final titles = ins.difficulties.map((d) => d.title).toList();
    expect(titles.first, 'Đang kẹt ở màn 13'); // most important first (5 tries)
    expect(
      titles,
      containsAll([
        'Thường chờ gợi ý mới bắt đầu',
        'Còn nhầm thứ tự từ',
        'Ít khi nói to câu',
        'Hay bỏ dở giữa màn',
      ]),
    );
    expect(ins.difficulties.every((d) => d.tip.length > 30), isTrue);
    final initiation = ins.skills.firstWhere((s) => s.id == 'initiation');
    expect(initiation.level, SkillLevel.beginning);
  });
}
