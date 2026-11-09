// Turns the on-device event log into plain-language insights for parents:
// which skills the games practise (and how the child is doing), how interested the child is,
// and what is hard for the child — each difficulty comes with a tip for home.
//
// Pure logic (no widgets) so it can be unit-tested with synthetic event logs.
import 'dart:math';

import '../core/content/foods.dart';
import '../core/content/lang.dart';
import '../core/content/songs.dart';
import '../core/progress/event_log.dart';
import '../core/progress/profile.dart';

enum Trend { up, flat, down, unknown }

enum SkillLevel { noData, beginning, progressing, strong }

enum Interest { noData, low, warmingUp, interested, veryInterested }

enum Severity { info, watch, important }

class SkillInsight {
  SkillInsight({
    required this.id,
    required this.emoji,
    required this.title,
    required this.what,
    required this.how,
    required this.metric,
    required this.progress,
    required this.level,
    required this.trend,
    required this.samples,
  });
  final String id, emoji, title;

  /// Why this skill matters.
  final String what;

  /// Where the app practises it.
  final String how;

  /// Main numbers in plain words.
  final String metric;

  /// 0..1 for a progress bar (null = no data).
  final double? progress;
  final SkillLevel level;
  final Trend trend;
  final int samples;
}

class Engagement {
  Engagement({
    required this.minutesByDay,
    required this.daysActive,
    required this.avgMinutesActiveDay,
    required this.sessions,
    required this.quitRate,
    required this.restarts,
    required this.favorites,
    required this.calmUses,
    required this.interest,
    required this.interestReason,
  });

  /// Last 7 days, oldest first: (short label, minutes).
  final List<(String, int)> minutesByDay;
  final int daysActive, sessions, restarts, calmUses;
  final double avgMinutesActiveDay;

  /// Share of started levels the child left before the end (0..1, null = no data).
  final double? quitRate;

  /// "What the child likes": label -> value text.
  final List<(String, String)> favorites;
  final Interest interest;
  final String interestReason;
}

class Difficulty {
  Difficulty(this.severity, this.title, this.detail, this.tip);
  final Severity severity;
  final String title, detail, tip;
}

class ParentInsights {
  ParentInsights({
    required this.skills,
    required this.engagement,
    required this.difficulties,
    required this.highlights,
    required this.totalEvents,
  });
  final List<SkillInsight> skills;
  final Engagement engagement;
  final List<Difficulty> difficulties;
  final List<String> highlights;
  final int totalEvents;

  bool get enoughData => totalEvents >= 15;
}

/// Compute insights from the event log. [now] is injectable for tests.
ParentInsights computeInsights(
  List<GameEvent> events,
  ChildProfile profile,
  Lang lang, {
  DateTime? now,
}) {
  final vi = lang == Lang.vi;
  String t(String en, String v) => vi ? v : en;
  final today = now ?? DateTime.now();

  List<GameEvent> of(String type) =>
      events.where((e) => e.type == type).toList();
  final starts = of('start');
  final sents = of('sentence');
  final sings = of('sing_song');
  final picks = of('sing_pick');
  final levelStarts = of('level_start');
  final levelEnds = of('level');
  final quits = of('quit');
  final restarts = of('restart');

  double rate(Iterable<bool> xs) =>
      xs.isEmpty ? 0 : xs.where((x) => x).length / xs.length;
  double avg(Iterable<num> xs) =>
      xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;
  int pct(double r) => (r * 100).round();

  /// Compare the recent part of [xs] (chronological) with the part just before it.
  /// Rates (0..1) compare by absolute difference; times ([relative]) by relative change.
  Trend trendOf(
    List<double> xs, {
    bool lowerIsBetter = false,
    bool relative = false,
    double minDelta = 0.1,
  }) {
    if (xs.length < 6) return Trend.unknown;
    final n = min(10, xs.length ~/ 2);
    final recent = avg(xs.sublist(xs.length - n));
    final before = avg(xs.sublist(xs.length - 2 * n, xs.length - n));
    var d = relative ? (recent - before) / max(before, 0.5) : recent - before;
    if (lowerIsBetter) d = -d;
    if (d > minDelta) return Trend.up;
    if (d < -minDelta) return Trend.down;
    return Trend.flat;
  }

  SkillLevel levelOf(double? v, int samples, double good, double ok) {
    if (v == null || samples == 0) return SkillLevel.noData;
    if (v >= good) return SkillLevel.strong;
    if (v >= ok) return SkillLevel.progressing;
    return SkillLevel.beginning;
  }

  // ---------------------------------------------------------------- skills
  final skills = <SkillInsight>[];

  // 1. Initiation
  final selfRate = rate(starts.map((e) => e.get<bool>('selfStart') == true));
  final avgStartSec = avg(
    starts.reversed.take(10).map((e) => (e.get<int>('latency') ?? 0) / 1000),
  );
  skills.add(
    SkillInsight(
      id: 'initiation',
      emoji: '🚀',
      title: t('Starting on their own', 'Tự bắt đầu'),
      what: t(
        'Starting an activity without being told — the first step to doing things independently.',
        'Tự bắt đầu một việc mà không cần ai nhắc — bước đầu tiên để tự lập.',
      ),
      how: t(
        'Every "Play / Let\'s go / Let\'s sing" button waits for the child. Starting before the glow appears earns a star; the glow then waits longer next time.',
        'Mọi nút "Chơi / Bắt đầu / Cùng hát" đều chờ bé. Bé bấm trước khi nút sáng thì được thưởng sao; lần sau nút chờ lâu hơn.',
      ),
      metric: starts.isEmpty
          ? t('No data yet', 'Chưa có dữ liệu')
          : t(
              'Started alone ${starts.where((e) => e.get<bool>('selfStart') == true).length} of ${starts.length} times (${pct(selfRate)}%) · usually starts in ${avgStartSec.toStringAsFixed(1)} s',
              'Tự bắt đầu ${starts.where((e) => e.get<bool>('selfStart') == true).length}/${starts.length} lần (${pct(selfRate)}%) · thường bắt đầu sau ${avgStartSec.toStringAsFixed(1)} giây',
            ),
      progress: starts.isEmpty ? null : selfRate,
      level: levelOf(
        starts.isEmpty ? null : selfRate,
        starts.length,
        0.6,
        0.25,
      ),
      trend: trendOf([
        for (final e in starts) e.get<bool>('selfStart') == true ? 1.0 : 0.0,
      ]),
      samples: starts.length,
    ),
  );

  // 2. Building sentences
  final noHintRate = rate(
    sents.map(
      (e) => (e.get<int>('wrong') ?? 0) == 0 && (e.get<int>('hints') ?? 0) == 0,
    ),
  );
  final avgLen = avg(sents.map((e) => e.get<int>('words') ?? 0));
  final helpLevel = max(profile.hintFor(Lang.en), profile.hintFor(Lang.vi));
  skills.add(
    SkillInsight(
      id: 'sentences',
      emoji: '🧩',
      title: t('Building sentences', 'Ghép câu'),
      what: t(
        'Putting words in the right order to ask for something ("Can I have an orange, please?").',
        'Sắp xếp từ đúng thứ tự để xin một thứ ("Cho tôi xin quả cam ạ").',
      ),
      how: t(
        'After each order the child picks a treat and builds the request from word tiles. Help fades: full sentence → first word → no hints.',
        'Sau mỗi đơn hàng, bé chọn món và ghép câu xin món từ các thẻ chữ. Gợi ý giảm dần: cả câu mẫu → từ đầu tiên → không gợi ý.',
      ),
      metric: sents.isEmpty
          ? t('No data yet', 'Chưa có dữ liệu')
          : t(
              '${sents.length} sentences · ${avgLen.toStringAsFixed(1)} words on average · ${pct(noHintRate)}% without any help · help now: ${['full model', 'first word', 'none'][helpLevel]}',
              '${sents.length} câu · trung bình ${avgLen.toStringAsFixed(1)} từ · ${pct(noHintRate)}% không cần trợ giúp · mức gợi ý hiện tại: ${['cả câu mẫu', 'từ đầu tiên', 'không gợi ý'][helpLevel]}',
            ),
      progress: sents.isEmpty ? null : noHintRate,
      level: levelOf(
        sents.isEmpty ? null : noHintRate,
        sents.length,
        0.7,
        0.35,
      ),
      trend: trendOf([
        for (final e in sents)
          ((e.get<int>('wrong') ?? 0) == 0 && (e.get<int>('hints') ?? 0) == 0)
              ? 1.0
              : 0.0,
      ]),
      samples: sents.length,
    ),
  );

  // 3. Speaking aloud
  final spokeSent = sents.where((e) => e.get<bool>('spoke') == true).length;
  final sayTotal = sings.fold<int>(0, (a, e) => a + (e.get<int>('say') ?? 0));
  final sayVoiced = sings.fold<int>(
    0,
    (a, e) => a + (e.get<int>('sayVoiced') ?? 0),
  );
  final singLines = sings.fold<int>(
    0,
    (a, e) => a + (e.get<int>('lines') ?? 0),
  );
  final singVoiced = sings.fold<int>(
    0,
    (a, e) => a + (e.get<int>('voiced') ?? 0),
  );
  final speakChances = sents.length + sayTotal;
  final speakRate = speakChances == 0
      ? 0.0
      : (spokeSent + sayVoiced) / speakChances;
  skills.add(
    SkillInsight(
      id: 'speaking',
      emoji: '🗣️',
      title: t('Speaking out loud', 'Nói thành tiếng'),
      what: t(
        'Using the voice to say full sentences, not just single words.',
        'Dùng giọng nói để nói cả câu, không chỉ một từ.',
      ),
      how: t(
        'After building a sentence the child is invited (never forced) to say it. In Sing & Say, singing leads into saying the key sentences.',
        'Sau khi ghép câu, bé được mời (không ép) nói to câu đó. Trong Hát & Nói, bé hát rồi nói lại các câu quan trọng.',
      ),
      metric: speakChances == 0
          ? t('No data yet', 'Chưa có dữ liệu')
          : t(
              'Said it aloud ${spokeSent + sayVoiced} of $speakChances times (${pct(speakRate)}%)${singLines > 0 ? ' · sang along on ${pct(singVoiced / singLines)}% of song lines' : ''}',
              'Đã nói to ${spokeSent + sayVoiced}/$speakChances lần (${pct(speakRate)}%)${singLines > 0 ? ' · hát theo ${pct(singVoiced / singLines)}% câu hát' : ''}',
            ),
      progress: speakChances == 0 ? null : speakRate,
      level: levelOf(
        speakChances == 0 ? null : speakRate,
        speakChances,
        0.6,
        0.25,
      ),
      trend: trendOf([
        for (final e in sents) e.get<bool>('spoke') == true ? 1.0 : 0.0,
      ]),
      samples: speakChances,
    ),
  );

  // 4. Making choices
  final choiceSecs = [
    for (final e in sents)
      if (e.get<int>('choiceMs') != null) e.get<int>('choiceMs')! / 1000,
    for (final e in picks)
      if (e.get<int>('latency') != null) e.get<int>('latency')! / 1000,
  ];
  final avgChoice = avg(choiceSecs.reversed.take(10));
  final choiceScore = choiceSecs.isEmpty
      ? null
      : (1 - (avgChoice / 15)).clamp(0.0, 1.0);
  skills.add(
    SkillInsight(
      id: 'choices',
      emoji: '☝️',
      title: t('Making choices', 'Tự lựa chọn'),
      what: t(
        'Deciding what they want — choosing is a form of self-expression and self-starting.',
        'Tự quyết định mình muốn gì — chọn lựa cũng là tự thể hiện và tự bắt đầu.',
      ),
      how: t(
        'The child chooses a treat after each level and chooses songs in Sing & Say.',
        'Bé tự chọn món sau mỗi màn và tự chọn bài hát trong Hát & Nói.',
      ),
      metric: choiceSecs.isEmpty
          ? t('No data yet', 'Chưa có dữ liệu')
          : t(
              '${choiceSecs.length} choices · usually decides in ${avgChoice.toStringAsFixed(1)} s',
              '${choiceSecs.length} lần chọn · thường quyết định trong ${avgChoice.toStringAsFixed(1)} giây',
            ),
      progress: choiceScore,
      level: levelOf(choiceScore, choiceSecs.length, 0.6, 0.3),
      trend: trendOf(
        choiceSecs,
        lowerIsBetter: true,
        relative: true,
        minDelta: 0.15,
      ),
      samples: choiceSecs.length,
    ),
  );

  // 5. Problem solving & focus (the match-3 board)
  final wins = levelEnds.where((e) => e.get<String>('result') == 'win').length;
  final attempts = levelStarts.length;
  final winRate = attempts == 0 ? 0.0 : wins / attempts;
  final reached = profile.gameLevels.values.fold<int>(0, max);
  skills.add(
    SkillInsight(
      id: 'focus',
      emoji: '🧠',
      title: t('Problem solving & focus', 'Giải đố & tập trung'),
      what: t(
        'Looking for patterns, planning a move and staying with a task until it is done.',
        'Tìm quy luật, tính một nước đi và kiên trì làm đến khi xong.',
      ),
      how: t(
        'Matching fruits to complete orders, breaking ice and walls, using special pieces.',
        'Ghép trái cây để hoàn thành đơn hàng, phá băng, phá tường, dùng viên đặc biệt.',
      ),
      metric: attempts == 0
          ? t('No data yet', 'Chưa có dữ liệu')
          : t(
              'Finished $wins of $attempts levels played (${pct(winRate)}%) · reached level ${reached + 1}',
              'Hoàn thành $wins/$attempts lượt chơi (${pct(winRate)}%) · đã đến màn ${reached + 1}',
            ),
      progress: attempts == 0 ? null : winRate,
      level: levelOf(attempts == 0 ? null : winRate, attempts, 0.6, 0.3),
      trend: trendOf([
        for (final e in levelEnds) e.get<String>('result') == 'win' ? 1.0 : 0.0,
      ]),
      samples: attempts,
    ),
  );

  // 6. Counting (bonus tasks when out of moves)
  final countEvents = of('count');
  final countFirstTry = rate(
    countEvents.map((e) => (e.get<int>('wrong') ?? 0) == 0),
  );
  skills.add(
    SkillInsight(
      id: 'counting',
      emoji: '🔢',
      title: t('Counting', 'Đếm số'),
      what: t(
        'Counting things and picking the matching number — the base for money and everyday maths.',
        'Đếm đồ vật và chọn đúng con số — nền tảng cho việc dùng tiền và toán hằng ngày.',
      ),
      how: t(
        'When the moves run out, the child can earn 5 more moves by counting fruits or by asking nicely.',
        'Khi hết lượt, bé có thể được thêm 5 lượt bằng cách đếm trái cây hoặc xin lễ phép.',
      ),
      metric: countEvents.isEmpty
          ? t('No data yet', 'Chưa có dữ liệu')
          : t(
              'Counted right the first time in ${countEvents.where((e) => (e.get<int>('wrong') ?? 0) == 0).length} of ${countEvents.length} tasks (${pct(countFirstTry)}%)',
              'Đếm đúng ngay lần đầu ${countEvents.where((e) => (e.get<int>('wrong') ?? 0) == 0).length}/${countEvents.length} bài (${pct(countFirstTry)}%)',
            ),
      progress: countEvents.isEmpty ? null : countFirstTry,
      level: levelOf(
        countEvents.isEmpty ? null : countFirstTry,
        countEvents.length,
        0.7,
        0.4,
      ),
      trend: trendOf([
        for (final e in countEvents)
          (e.get<int>('wrong') ?? 0) == 0 ? 1.0 : 0.0,
      ]),
      samples: countEvents.length,
    ),
  );

  // ---------------------------------------------------------------- engagement
  final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
  final minutesByDay = [
    for (final d in days)
      (
        '${d.day}/${d.month}',
        ((profile.playMs[dayKey(d)] ?? 0) / 60000).round(),
      ),
  ];
  final weekStart = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(days: 6));
  final weekEvents = events.where((e) => !e.time.isBefore(weekStart)).toList();
  final activeDayKeys = {
    for (final e in weekEvents) dayKey(e.time),
    for (final d in days)
      if ((profile.playMs[dayKey(d)] ?? 0) > 0) dayKey(d),
  };
  final daysActive = activeDayKeys.length;
  final activeMinutes = minutesByDay.where((m) => m.$2 > 0).map((m) => m.$2);
  final avgActiveMin = avg(activeMinutes);
  final sessions = weekEvents.where((e) => e.type == 'app_open').length;
  final quitRate = attempts == 0
      ? null
      : (quits.length / attempts).clamp(0.0, 1.0);

  String? topOf(Iterable<String> xs) {
    final c = <String, int>{};
    for (final x in xs) {
      c[x] = (c[x] ?? 0) + 1;
    }
    if (c.isEmpty) return null;
    return (c.entries.toList()..sort((a, b) => b.value - a.value)).first.key;
  }

  final favorites = <(String, String)>[];
  final snackPlays = levelStarts.length,
      singPlays = sings.length + picks.length;
  if (snackPlays + singPlays > 0) {
    favorites.add((
      t('Most played', 'Chơi nhiều nhất'),
      snackPlays >= singPlays
          ? 'Snack Beats 🍓'
          : t('Sing & Say 🎤', 'Hát & Nói 🎤'),
    ));
  }
  final favFood = topOf([
    for (final e in sents)
      if (e.get<int>('food') != null && e.get<int>('food')! < foods.length)
        '${foods[e.get<int>('food')!].emoji} ${foods[e.get<int>('food')!].words(lang).name}',
  ]);
  if (favFood != null) {
    favorites.add((t('Favourite treat', 'Món hay chọn'), favFood));
  }
  final favSong = topOf([
    for (final e in of('music'))
      if (e.get<int>('song') != null && e.get<int>('song')! < songs.length)
        songs[e.get<int>('song')!].title(lang),
  ]);
  if (favSong != null) {
    favorites.add((t('Favourite music', 'Bài nhạc hay nghe'), favSong));
  }
  final favSingSong = topOf([
    for (final e in picks) e.get<String>('song') ?? '',
  ]);
  if (favSingSong != null && favSingSong.isNotEmpty) {
    favorites.add((t('Favourite song to sing', 'Bài hay hát'), favSingSong));
  }
  final calmUses = of('calm').length;

  Interest interest;
  String reason;
  if (weekEvents.isEmpty && minutesByDay.every((m) => m.$2 == 0)) {
    interest = Interest.noData;
    reason = t('No play this week yet.', 'Tuần này bé chưa chơi.');
  } else {
    final score =
        (daysActive / 7) * 0.4 +
        min(avgActiveMin / 15, 1.0) * 0.3 +
        (1 - (quitRate ?? 0)) * 0.3;
    interest = score >= 0.7
        ? Interest.veryInterested
        : score >= 0.45
        ? Interest.interested
        : score >= 0.2
        ? Interest.warmingUp
        : Interest.low;
    reason = t(
      'Played on $daysActive of the last 7 days, about ${avgActiveMin.round()} min on a play day${quitRate == null ? '' : ', left ${pct(quitRate)}% of levels early'}.',
      'Bé chơi $daysActive/7 ngày gần đây, khoảng ${avgActiveMin.round()} phút mỗi ngày có chơi${quitRate == null ? '' : ', bỏ dở ${pct(quitRate)}% số màn'}.',
    );
  }

  final engagement = Engagement(
    minutesByDay: minutesByDay,
    daysActive: daysActive,
    avgMinutesActiveDay: avgActiveMin.toDouble(),
    sessions: sessions,
    quitRate: quitRate,
    restarts: restarts.length,
    favorites: favorites,
    calmUses: calmUses,
    interest: interest,
    interestReason: reason,
  );

  // ---------------------------------------------------------------- difficulties (with tips)
  final diffs = <Difficulty>[];

  // Stuck levels: tried >= 3 times, never won.
  final tries = <int, int>{};
  for (final e in levelStarts) {
    final lv = e.get<int>('level');
    if (lv != null) tries[lv] = (tries[lv] ?? 0) + 1;
  }
  final won = {
    for (final e in levelEnds)
      if (e.get<String>('result') == 'win') e.get<int>('level'),
  };
  final stuck =
      tries.entries.where((e) => e.value >= 3 && !won.contains(e.key)).toList()
        ..sort((a, b) => b.value - a.value);
  if (stuck.isNotEmpty) {
    final s = stuck.first;
    diffs.add(
      Difficulty(
        Severity.important,
        t('Stuck on level ${s.key + 1}', 'Đang kẹt ở màn ${s.key + 1}'),
        t(
          'Tried ${s.value} times without finishing it.',
          'Đã thử ${s.value} lần mà chưa qua được.',
        ),
        t(
          'Sit with your child for one try. Point at three matching fruits and say "Look — three oranges!", then let them make the move. Celebrate the attempt, not only the win.',
          'Ngồi chơi cùng bé một lượt. Chỉ vào 3 trái cây giống nhau và nói "Nhìn này — 3 quả cam!", rồi để bé tự đi nước đó. Khen cả khi bé cố gắng, không chỉ khi thắng.',
        ),
      ),
    );
  }
  if (starts.length >= 5 && selfRate < 0.4) {
    diffs.add(
      Difficulty(
        Severity.watch,
        t('Usually waits for a cue to start', 'Thường chờ gợi ý mới bắt đầu'),
        t(
          'Started alone in ${pct(selfRate)}% of chances.',
          'Chỉ tự bắt đầu ${pct(selfRate)}% số lần.',
        ),
        t(
          'This is the main thing the app trains — it is normal at first. At home, wait 5–10 seconds before prompting, use a gesture instead of words, and praise warmly whenever they start alone.',
          'Đây là kỹ năng chính app luyện — lúc đầu như vậy là bình thường. Ở nhà, hãy chờ 5–10 giây trước khi nhắc, dùng cử chỉ thay vì lời nói, và khen thật nhiều mỗi khi bé tự bắt đầu.',
        ),
      ),
    );
  }
  final avgWrong = avg(
    sents.reversed.take(10).map((e) => e.get<int>('wrong') ?? 0),
  );
  if (sents.length >= 5 && avgWrong >= 1.5) {
    diffs.add(
      Difficulty(
        Severity.watch,
        t('Mixes up the word order', 'Còn nhầm thứ tự từ'),
        t(
          'About ${avgWrong.toStringAsFixed(1)} wrong taps per sentence lately.',
          'Gần đây khoảng ${avgWrong.toStringAsFixed(1)} lần chọn sai mỗi câu.',
        ),
        t(
          'Say the sentence slowly together and tap the table once per word. Short, real requests at meals ("I want water") help a lot. If it feels like a chore, set "Sentence practice" to every 2 levels in Settings.',
          'Cùng bé đọc chậm câu và gõ nhẹ xuống bàn theo từng từ. Tập những câu xin thật ngắn trong bữa ăn ("Con muốn uống nước") giúp rất nhiều. Nếu bé thấy ghép câu là gánh nặng, hãy chọn "Ghép câu: 2 màn một lần" trong Cài đặt.',
        ),
      ),
    );
  }
  if (speakChances >= 5 && speakRate < 0.3) {
    diffs.add(
      Difficulty(
        Severity.watch,
        t('Rarely says the sentence aloud', 'Ít khi nói to câu'),
        t(
          'Said it aloud in ${pct(speakRate)}% of chances.',
          'Chỉ nói to ${pct(speakRate)}% số lần.',
        ),
        t(
          'Never force it. Say the sentence yourself with a smile and pause — copying a model is easier. Singing first (Sing & Say) often unlocks speaking.',
          'Đừng ép bé. Bạn hãy nói câu đó trước với nụ cười rồi dừng lại chờ — bắt chước mẫu dễ hơn. Hát trước (Hát & Nói) thường giúp bé dễ nói hơn.',
        ),
      ),
    );
  }
  if (attempts >= 5 && (quitRate ?? 0) >= 0.3) {
    diffs.add(
      Difficulty(
        Severity.watch,
        t('Often leaves levels early', 'Hay bỏ dở giữa màn'),
        t(
          'Left ${pct(quitRate!)}% of levels before the end.',
          'Bỏ dở ${pct(quitRate)}% số màn.',
        ),
        t(
          'The levels may feel long or the screen too busy. Try shorter sessions, set "Visual effects: Soft" below, and stop while it is still fun.',
          'Có thể màn chơi hơi dài hoặc màn hình quá rộn ràng. Hãy cho chơi ngắn hơn, chọn "Hiệu ứng: Nhẹ nhàng" bên dưới, và dừng khi bé vẫn còn vui.',
        ),
      ),
    );
  }
  if (restarts.length >= 5 &&
      attempts > 0 &&
      restarts.length / attempts > 0.4) {
    diffs.add(
      Difficulty(
        Severity.info,
        t('Restarts levels a lot', 'Hay chơi lại màn'),
        t('${restarts.length} restarts.', '${restarts.length} lần chơi lại.'),
        t(
          'Restarting can be a way to avoid frustration — that is OK. If it happens on one level, play that level together.',
          'Chơi lại có thể là cách bé tránh bực bội — không sao cả. Nếu lặp lại ở một màn, hãy chơi màn đó cùng bé.',
        ),
      ),
    );
  }
  if (avgStartSec > 10 && starts.length >= 5) {
    diffs.add(
      Difficulty(
        Severity.info,
        t('Takes a long time to start', 'Mất nhiều thời gian để bắt đầu'),
        t(
          'Usually ${avgStartSec.toStringAsFixed(0)} s before starting.',
          'Thường ${avgStartSec.toStringAsFixed(0)} giây mới bắt đầu.',
        ),
        t(
          'Give the child time — the app waits patiently and the glow gives a gentle hint. Avoid tapping for them.',
          'Hãy cho bé thời gian — app chờ rất kiên nhẫn và nút sáng lên là gợi ý nhẹ. Tránh bấm hộ bé.',
        ),
      ),
    );
  }
  if (countEvents.length >= 4 && countFirstTry < 0.5) {
    diffs.add(
      Difficulty(
        Severity.watch,
        t('Counting is still tricky', 'Đếm số còn khó'),
        t(
          'Counted right the first time in ${pct(countFirstTry)}% of tasks.',
          'Chỉ đếm đúng ngay lần đầu ${pct(countFirstTry)}% số bài.',
        ),
        t(
          'Count real things together every day (spoons, steps, fruit), touching each one as you say the number. The 🔊 "Count with me" button counts out loud too.',
          'Mỗi ngày cùng bé đếm đồ vật thật (thìa, bậc thang, trái cây), chạm vào từng thứ khi đọc số. Nút 🔊 "Đếm cùng mình" cũng đếm to cho bé nghe.',
        ),
      ),
    );
  }
  diffs.sort((a, b) => b.severity.index - a.severity.index);

  // ---------------------------------------------------------------- highlights
  final highlights = <String>[];
  for (final s in skills) {
    if (s.trend == Trend.up) {
      highlights.add(
        t(
          'Getting better at: ${s.title} ${s.emoji}',
          'Đang tiến bộ: ${s.title} ${s.emoji}',
        ),
      );
    }
  }
  if (helpLevel == 2) {
    highlights.add(
      t(
        'Builds sentences with no hints now 🧩',
        'Đã ghép câu không cần gợi ý 🧩',
      ),
    );
  }
  final longest = sents.fold<int>(
    0,
    (a, e) => max(a, e.get<int>('words') ?? 0),
  );
  if (longest >= 5) {
    highlights.add(
      t('Longest sentence: $longest words', 'Câu dài nhất: $longest từ'),
    );
  }
  if (profile.songs.isNotEmpty) {
    highlights.add(
      t(
        '${profile.songs.length} songs unlocked 🎵',
        'Đã mở ${profile.songs.length} bài hát 🎵',
      ),
    );
  }
  if (wins > 0) {
    highlights.add(t('$wins levels completed ⭐', 'Hoàn thành $wins màn ⭐'));
  }

  return ParentInsights(
    skills: skills,
    engagement: engagement,
    difficulties: diffs,
    highlights: highlights,
    totalEvents: events.length,
  );
}
