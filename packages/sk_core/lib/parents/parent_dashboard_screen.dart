import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/lang.dart';
import '../core/progress/event_log.dart';
import '../core/progress/profile.dart';
import '../core/speech/speech_service.dart';
import '../core/ui/palette.dart';
import '../core/ui/theme.dart';
import '../core/ui/widgets.dart';
import '../l10n/app_localizations.dart';
import '../core/skills/skills.dart';
import '../core/update/update_checker.dart';
import 'insights.dart';

/// Parent area: what the app teaches, how the child is doing, interest, difficulties + tips, settings.
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});
  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  late final Future<(bool, bool)> _voices = () async {
    final s = ref.read(speechProvider);
    return (await s.hasVoice(Lang.en), await s.hasVoice(Lang.vi));
  }();

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider);
    final log = ref.read(eventLogProvider);
    final vi = p.lang == Lang.vi;
    String t(String en, String v) => vi ? v : en;
    final ins = computeInsights(log.events, p, p.lang);
    final l = AppLocalizations.of(context);

    final tabs = [
      (t('Overview', 'Tổng quan'), '🏠'),
      (t('Skills', 'Kỹ năng'), '🎯'),
      (t('Interest', 'Hứng thú'), '💛'),
      (t('Difficulties', 'Khó khăn'), '🧭'),
      (t('Lessons', 'Bài học'), '🧩'),
      (t('Settings', 'Cài đặt'), '⚙️'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: AppScreen(
        child: Column(
          children: [
            Row(
              children: [
                const HomeBtn(),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l.pTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.text,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Pure.blue,
                  borderRadius: BorderRadius.circular(14),
                ),
                tabs: [
                  for (final (name, icon) in tabs) Tab(text: '$icon  $name'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _page([..._overview(ins, t)]),
                  _page([..._skills(ins, t)]),
                  _page([..._interest(ins, t)]),
                  _page([..._difficulties(ins, t)]),
                  _page([..._lessons(p, l, t)]),
                  _page([..._settings(p, l, t)]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(List<Widget> children) => ListView(
    padding: const EdgeInsets.only(bottom: 30),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );

  // ------------------------------------------------------------------ building blocks
  static Widget _card({required Widget child, Color? color, Color? border}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: border == null ? null : Border.all(color: border, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  static Widget _h(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
    child: Text(
      s,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    ),
  );

  static (String, Color) _levelBadge(
    SkillLevel lv,
    String Function(String, String) t,
  ) => switch (lv) {
    SkillLevel.noData => (
      t('No data yet', 'Chưa có dữ liệu'),
      const Color(0xFF90A4AE),
    ),
    SkillLevel.beginning => (t('Just starting', 'Mới bắt đầu'), Pure.orange),
    SkillLevel.progressing => (t('Making progress', 'Đang tiến bộ'), Pure.blue),
    SkillLevel.strong => (t('Doing well', 'Làm tốt'), Pure.green),
  };

  static (String, Color)? _trendBadge(
    Trend tr,
    String Function(String, String) t,
  ) => switch (tr) {
    Trend.up => (t('↑ improving', '↑ đang tốt lên'), Pure.green),
    Trend.flat => (t('→ steady', '→ ổn định'), const Color(0xFF78909C)),
    Trend.down => (t('↓ dipping lately', '↓ gần đây giảm'), Pure.orange),
    Trend.unknown => null,
  };

  static Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
    ),
  );

  static (String, String) _interestFace(
    Interest i,
    String Function(String, String) t,
  ) => switch (i) {
    Interest.veryInterested => ('🤩', t('Very interested', 'Rất hứng thú')),
    Interest.interested => ('😊', t('Interested', 'Có hứng thú')),
    Interest.warmingUp => ('🙂', t('Getting used to it', 'Đang làm quen')),
    Interest.low => ('😐', t('Not playing much', 'Ít chơi')),
    Interest.noData => ('🌱', t('No play yet', 'Chưa có dữ liệu')),
  };

  Widget _interestCard(ParentInsights ins, String Function(String, String) t) {
    final (face, label) = _interestFace(ins.engagement.interest, t);
    return _card(
      child: Row(
        children: [
          Text(face, style: const TextStyle(fontSize: 54)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Interest', 'Mức hứng thú'),
                  style: const TextStyle(color: AppColors.muted),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(ins.engagement.interestReason),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillRow(SkillInsight s, String Function(String, String) t) {
    final (lvText, lvColor) = _levelBadge(s.level, t);
    final tr = _trendBadge(s.trend, t);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(s.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(lvText, lvColor),
                    if (tr != null) _chip(tr.$1, tr.$2),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _difficultyCard(Difficulty d, String Function(String, String) t) {
    final color = switch (d.severity) {
      Severity.important => Pure.red,
      Severity.watch => Pure.orange,
      Severity.info => Pure.blue,
    };
    return _card(
      border: color.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(d.detail, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: t('At home: ', 'Gợi ý ở nhà: '),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: d.tip),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noDataNote(String Function(String, String) t) => _card(
    color: const Color(0xFFE3F2FD),
    child: Text(
      t(
        '🌱 Not much play yet. Insights get more accurate after a few days of play.',
        '🌱 Bé mới chơi ít. Nhận xét sẽ chính xác hơn sau vài ngày chơi.',
      ),
    ),
  );

  // ------------------------------------------------------------------ tabs
  Iterable<Widget> _overview(
    ParentInsights ins,
    String Function(String, String) t,
  ) sync* {
    final update = ref.watch(appUpdateProvider);
    if (update != null) {
      yield _card(
        color: const Color(0xFFE8F5E9),
        border: Pure.green,
        child: Row(
          children: [
            const Text('⬇️', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(
                      'New version ${update.version} is available',
                      'Đã có bản mới ${update.version}',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (update.notes.isNotEmpty)
                    Text(
                      update.notes,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  Text(
                    t(
                      'Your child\'s progress is kept.',
                      'Tiến trình của bé được giữ nguyên.',
                    ),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Pure.green),
              onPressed: () => openUpdate(update),
              child: Text(t('Download', 'Tải về')),
            ),
          ],
        ),
      );
    }
    if (!ins.enoughData) yield _noDataNote(t);
    yield _interestCard(ins, t);
    yield _h(t('What the app is teaching', 'App đang dạy bé'));
    yield _card(
      child: Column(children: [for (final s in ins.skills) _skillRow(s, t)]),
    );
    if (ins.highlights.isNotEmpty) {
      yield _h(t('Bright spots', 'Điểm sáng'));
      yield _card(
        color: const Color(0xFFE8F5E9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final h in ins.highlights)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '🌟  $h',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (ins.difficulties.isNotEmpty) {
      yield _h(t('Needs attention', 'Cần chú ý'));
      yield _difficultyCard(ins.difficulties.first, t);
      if (ins.difficulties.length > 1) {
        yield Text(
          t(
            '+ ${ins.difficulties.length - 1} more in "Difficulties"',
            '+ ${ins.difficulties.length - 1} điều nữa trong mục "Khó khăn"',
          ),
          style: const TextStyle(color: AppColors.muted),
        );
      }
    }
    yield const SizedBox(height: 8);
    yield Text(
      t('All data stays on this device.', 'Mọi dữ liệu chỉ lưu trên máy này.'),
      style: const TextStyle(color: AppColors.muted),
    );
  }

  Iterable<Widget> _skills(
    ParentInsights ins,
    String Function(String, String) t,
  ) sync* {
    yield Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        t(
          'Each game is built to practise real-life skills. Here is what each one means and how your child is doing.',
          'Mỗi trò chơi được thiết kế để luyện kỹ năng cho cuộc sống. Dưới đây là ý nghĩa từng kỹ năng và bé đang làm thế nào.',
        ),
        style: const TextStyle(color: AppColors.muted),
      ),
    );
    for (final s in ins.skills) {
      final (lvText, lvColor) = _levelBadge(s.level, t);
      final tr = _trendBadge(s.trend, t);
      yield _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(lvText, lvColor),
                if (tr != null) _chip(tr.$1, tr.$2),
              ],
            ),
            const SizedBox(height: 10),
            Text(s.what, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('🎮 ${s.how}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            Text(s.metric),
            if (s.progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: s.progress,
                  minHeight: 12,
                  color: lvColor,
                  backgroundColor: lvColor.withValues(alpha: 0.15),
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  Iterable<Widget> _interest(
    ParentInsights ins,
    String Function(String, String) t,
  ) sync* {
    final e = ins.engagement;
    yield _interestCard(ins, t);
    yield _h(t('Minutes played (last 7 days)', 'Số phút chơi (7 ngày qua)'));
    final maxMin = e.minutesByDay.fold<int>(1, (a, d) => d.$2 > a ? d.$2 : a);
    yield _card(
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (day, min) in e.minutesByDay)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$min',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 110 * (min / maxMin) + 4,
                        decoration: BoxDecoration(
                          color: min > 0 ? Pure.blue : const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        day,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    Widget stat(String label, String value) => Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
    yield _card(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          stat(
            t('Days played this week', 'Số ngày chơi tuần này'),
            '${e.daysActive}/7',
          ),
          stat(
            t('Minutes on a play day', 'Phút mỗi ngày có chơi'),
            e.avgMinutesActiveDay.round().toString(),
          ),
          stat(
            t('Times opened this week', 'Số lần mở app tuần này'),
            '${e.sessions}',
          ),
          stat(
            t('Levels left early', 'Màn bỏ dở'),
            e.quitRate == null ? '–' : '${(e.quitRate! * 100).round()}%',
          ),
          stat(t('Restarts', 'Lần chơi lại'), '${e.restarts}'),
          stat(t('Calm mode used', 'Dùng chế độ thư giãn'), '${e.calmUses}'),
        ],
      ),
    );
    if (e.favorites.isNotEmpty) {
      yield _h(t('What your child likes', 'Bé thích gì'));
      yield _card(
        child: Column(
          children: [
            for (final (k, v) in e.favorites)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        k,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    Text(
                      v,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
  }

  Iterable<Widget> _difficulties(
    ParentInsights ins,
    String Function(String, String) t,
  ) sync* {
    if (!ins.enoughData) {
      yield _noDataNote(t);
      return;
    }
    if (ins.difficulties.isEmpty) {
      yield _card(
        color: const Color(0xFFE8F5E9),
        child: Text(
          t(
            '🎉 Nothing worrying found. Keep playing together and praising effort!',
            '🎉 Chưa thấy khó khăn nào đáng lo. Hãy tiếp tục chơi cùng bé và khen sự cố gắng!',
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
      return;
    }
    yield Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        t(
          'Found automatically from how your child plays. Each one comes with something you can try at home.',
          'Được phát hiện tự động từ cách bé chơi. Mỗi điều đều kèm một gợi ý bạn có thể thử ở nhà.',
        ),
        style: const TextStyle(color: AppColors.muted),
      ),
    );
    for (final d in ins.difficulties) {
      yield _difficultyCard(d, t);
    }
  }

  // ------------------------------------------------------------------ lessons (child profile + skill set per game)
  static const _avatars = [
    '🧒',
    '👦',
    '👧',
    '🧑',
    '👱',
    '🧑‍🦱',
    '👩‍🦰',
    '🐯',
    '🐼',
    '🦊',
    '🐶',
    '🐱',
  ];

  Iterable<Widget> _lessons(
    ChildProfile p,
    AppLocalizations l,
    String Function(String, String) t,
  ) sync* {
    final notifier = ref.read(profileProvider.notifier);
    final specs = ref.read(gameSkillSpecsProvider);
    final engine = ref.read(skillEngineProvider);

    Widget levelPicker(
      String label,
      int value,
      List<String> names,
      void Function(int) set,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < names.length; i++)
                ChoiceChip(
                  label: Text(names[i]),
                  selected: value == i,
                  selectedColor: Pure.blue,
                  labelStyle: TextStyle(
                    color: value == i ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => set(i),
                ),
            ],
          ),
        ],
      ),
    );

    // ---- who the child is
    yield _h(t("Your child's profile", 'Hồ sơ của bé'));
    yield _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.avatar, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('child-name'),
                  initialValue: p.name,
                  decoration: InputDecoration(labelText: t('Name', 'Tên')),
                  onChanged: (v) => notifier.update(
                    (pp) => pp.name = v.trim().isEmpty ? pp.name : v.trim(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<int?>(
                  initialValue: p.age,
                  decoration: InputDecoration(labelText: t('Age', 'Tuổi')),
                  items: [
                    for (final a in [null, for (var i = 4; i <= 25; i++) i])
                      DropdownMenuItem(
                        value: a,
                        child: Text(a?.toString() ?? '–'),
                      ),
                  ],
                  onChanged: (v) => notifier.update((pp) => pp.age = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              for (final a in _avatars)
                GestureDetector(
                  onTap: () => notifier.update((pp) => pp.avatar = a),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: p.avatar == a
                          ? Pure.yellow.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(a, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          levelPicker(t('Speaking', 'Nói'), p.speech, [
            t('A few words', 'Vài từ'),
            t('Short phrases', 'Cụm ngắn'),
            t('Full sentences', 'Câu đầy đủ'),
          ], (v) => notifier.update((pp) => pp.speech = v)),
          levelPicker(t('Reading', 'Đọc'), p.reading, [
            t('Not yet', 'Chưa đọc'),
            t('Simple words', 'Từ đơn giản'),
            t('Sentences', 'Đọc được câu'),
          ], (v) => notifier.update((pp) => pp.reading = v)),
          levelPicker(t('Counting', 'Đếm'), p.counting, [
            t('Not yet', 'Chưa đếm'),
            t('Up to 10', 'Đếm đến 10'),
            t('Can calculate', 'Tính toán được'),
          ], (v) => notifier.update((pp) => pp.counting = v)),
        ],
      ),
    );

    // ---- suggestion from the profile
    yield _card(
      color: const Color(0xFFFFF8E1),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(
                'Turn on the lessons that fit this profile (e.g. no word-tile lessons if your child does not read yet).',
                'Bật các bài học phù hợp với hồ sơ (ví dụ: tắt bài ghép thẻ chữ nếu bé chưa biết đọc).',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Pure.orange),
            onPressed: () {
              notifier.update((pp) {
                for (final spec in specs) {
                  pp.skills[spec.id] = {
                    for (final e in recommendSkills(spec, pp).entries)
                      e.key.name: e.value,
                  };
                  pp.afterEvery[spec.id] = pp.speech == Ability.notYet ? 2 : 1;
                }
              });
              showToast(
                context,
                t('Lessons updated ✨', 'Đã cập nhật bài học ✨'),
              );
            },
            child: Text(t('Suggest', 'Gợi ý')),
          ),
        ],
      ),
    );

    // ---- per game
    for (final spec in specs) {
      yield _h('${spec.emoji}  ${spec.title(p.lang)}');
      yield _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final MapEntry(key: slot, value: ids)
                in spec.slots.entries) ...[
              Text(
                slot.title(p.lang),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (slot == SkillSlot.afterLevel)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('How often', 'Tần suất'),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                      DropdownButton<int>(
                        value: engine.afterEvery(spec),
                        items: [
                          DropdownMenuItem(value: 1, child: Text(l.everyLevel)),
                          DropdownMenuItem(value: 2, child: Text(l.every2)),
                          DropdownMenuItem(value: 3, child: Text(l.every3)),
                          DropdownMenuItem(value: 0, child: Text(l.pOff)),
                        ],
                        onChanged: (v) => notifier.update(
                          (pp) => pp.afterEvery[spec.id] = v ?? 1,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final id in ids)
                if (moduleById(id) case final m?)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: engine.enabled(spec, slot).contains(id),
                    activeThumbColor: Pure.green,
                    title: Text(
                      '${m.emoji}  ${m.title(p.lang)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      m.desc(p.lang) +
                          (m.needsReading && p.reading == Ability.notYet
                              ? t(
                                  '  ⚠️ Uses written words.',
                                  '  ⚠️ Cần đọc chữ.',
                                )
                              : ''),
                    ),
                    onChanged: (on) => notifier.update((pp) {
                      final current = engine.enabled(spec, slot);
                      final next = on
                          ? [...current, id]
                          : current.where((x) => x != id).toList();
                      pp.skills.putIfAbsent(spec.id, () => {})[slot.name] = [
                        for (final x in ids)
                          if (next.contains(x)) x,
                      ];
                    }),
                  ),
              if (slot == SkillSlot.outOfMoves &&
                  engine.enabled(spec, slot).isEmpty)
                Text(
                  t(
                    'All off: the child can only restart the level.',
                    'Tắt hết: khi hết lượt bé chỉ có thể chơi lại màn.',
                  ),
                  style: const TextStyle(color: AppColors.muted),
                ),
              const Divider(height: 24),
            ],
          ],
        ),
      );
    }
    yield _h(t('Coming soon', 'Sắp có'));
    yield _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (emoji, en, vi) in upcomingSkills)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '$emoji  ${p.lang == Lang.vi ? vi : en}',
                style: const TextStyle(color: AppColors.muted, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  Iterable<Widget> _settings(
    ChildProfile p,
    AppLocalizations l,
    String Function(String, String) t,
  ) sync* {
    Widget row(String label, Widget control) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          control,
        ],
      ),
    );
    final notifier = ref.read(profileProvider.notifier);
    yield _card(
      child: Column(
        children: [
          row(
            l.pLang,
            DropdownButton<Lang>(
              value: p.lang,
              items: const [
                DropdownMenuItem(value: Lang.en, child: Text('English')),
                DropdownMenuItem(value: Lang.vi, child: Text('Tiếng Việt')),
              ],
              onChanged: (v) => notifier.update((pp) => pp.lang = v ?? pp.lang),
            ),
          ),
          row(
            l.pLimit,
            DropdownButton<int>(
              value: p.sessionLimitMin,
              items: [
                for (final m in const [0, 10, 15, 20, 30, 45])
                  DropdownMenuItem(
                    value: m,
                    child: Text(m == 0 ? l.pOff : l.minutesN(m)),
                  ),
              ],
              onChanged: (v) =>
                  notifier.update((pp) => pp.sessionLimitMin = v ?? 20),
            ),
          ),
          row(
            l.pEffects,
            DropdownButton<bool>(
              value: p.effectsSoft,
              items: [
                DropdownMenuItem(value: false, child: Text(l.effectsFull)),
                DropdownMenuItem(value: true, child: Text(l.effectsSoft)),
              ],
              onChanged: (v) =>
                  notifier.update((pp) => pp.effectsSoft = v ?? false),
            ),
          ),
        ],
      ),
    );
    yield _h(
      t('Help levels (adjust automatically)', 'Mức trợ giúp (tự điều chỉnh)'),
    );
    final helpNames = [l.helpFull, l.helpFirst, l.helpNone];
    yield _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ${l.pSentHelp} (EN): ${helpNames[p.hintFor(Lang.en)]}'),
          Text('• ${l.pSentHelp} (VI): ${helpNames[p.hintFor(Lang.vi)]}'),
          Text(
            '• ${l.pCue}: ${l.secondsN((p.cueDelayMs / 1000).toStringAsFixed(1))}',
          ),
        ],
      ),
    );
    yield _h(l.pVoices);
    yield _card(
      child: FutureBuilder<(bool, bool)>(
        future: _voices,
        builder: (_, snap) {
          final (en, vi) = snap.data ?? (true, true);
          String r(String name, bool ok) =>
              '• $name: ${ok ? '✅' : '⚠️ ${l.pVoiceMissing}'}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(r('English', en)), Text(r('Tiếng Việt', vi))],
          );
        },
      ),
    );
    yield _h(t('App version', 'Phiên bản'));
    yield _card(
      child: Consumer(
        builder: (context, ref, _) {
          final st = ref.watch(updateStatusProvider);
          final s = st.value;
          final String line;
          if (st.isLoading) {
            line = t('Checking…', 'Đang kiểm tra…');
          } else if (s == null) {
            line = '';
          } else if (!s.checked) {
            line = t(
              'Updates are not checked on this device.',
              'Thiết bị này không kiểm tra cập nhật.',
            );
          } else if (s.error != null) {
            line = t(
              'Could not check (${s.error}).',
              'Không kiểm tra được (${s.error}).',
            );
          } else if (s.update != null) {
            line = t(
              'New version ${s.update!.version} is available.',
              'Đã có bản mới ${s.update!.version}.',
            );
          } else {
            line = t('This is the latest version.', 'Đây là bản mới nhất.');
          }
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t('Installed', 'Đang dùng')}: ${s?.current ?? '…'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(line, style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              if (s?.update != null)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Pure.green),
                  onPressed: () => openUpdate(s!.update!),
                  child: Text(t('Download', 'Tải về')),
                )
              else
                OutlinedButton(
                  onPressed: () => ref.invalidate(updateStatusProvider),
                  child: Text(t('Check for updates', 'Kiểm tra cập nhật')),
                ),
            ],
          );
        },
      ),
    );
    yield const SizedBox(height: 8);
    yield Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFD50000),
          backgroundColor: const Color(0x22FF1744),
        ),
        onPressed: () => _confirmReset(l),
        child: Padding(padding: const EdgeInsets.all(8), child: Text(l.pReset)),
      ),
    );
  }

  Future<void> _confirmReset(AppLocalizations l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.pResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(eventLogProvider).clear();
    await ref.read(profileProvider.notifier).reset();
    if (mounted) setState(() {});
  }
}
