// SKILL SET framework: short skill lessons that are embedded into games.
//
//  * A game declares SLOTS where a lesson can appear (GameSkillSpec), e.g. after a won level,
//    or when the moves run out (the lesson earns extra moves).
//  * The SKILL MODULES below are reusable lessons (choose & ask, ask for help, counting, …).
//  * Parents switch modules on/off per game and per slot, and set how often the after-level
//    lesson appears — based on the child's profile (one child per device).
//  * The SkillEngine picks the next enabled lesson for a slot (round-robin), runs it, logs it.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/lang.dart';
import '../lessons/bonus_lesson_screen.dart';
import '../lessons/treat_lesson_screen.dart';
import '../progress/event_log.dart';
import '../progress/profile.dart';
import '../ui/routes.dart';

/// Where in a game a lesson can appear.
enum SkillSlot {
  afterLevel,
  outOfMoves;

  String title(Lang l) => switch (this) {
    SkillSlot.afterLevel =>
      l == Lang.vi ? 'Sau khi thắng màn' : 'After winning a level',
    SkillSlot.outOfMoves =>
      l == Lang.vi
          ? 'Khi hết lượt (làm bài để được +5 lượt)'
          : 'When moves run out (earn +5 moves)',
  };
}

enum SkillCategory { communication, choice, math, emotions, dailyLife }

/// What the game tells the lesson.
class SkillRequest {
  const SkillRequest({
    required this.game,
    required this.slot,
    this.levelIndex = 0,
    this.suggestedFood,
    this.customer = '🧑',
    this.reward = '+5',
  });
  final String game;
  final SkillSlot slot;
  final int levelIndex;
  final int? suggestedFood;
  final String customer;

  /// Shown to the child, e.g. "+5" moves.
  final String reward;
}

/// What the lesson tells the game (and the progress log).
class SkillOutcome {
  const SkillOutcome(
    this.module, {
    this.wrong = 0,
    this.hints = 0,
    this.spoke = false,
  });
  final String module;
  final int wrong, hints;
  final bool spoke;
}

class SkillModule {
  const SkillModule({
    required this.id,
    required this.emoji,
    required this.titleEn,
    required this.titleVi,
    required this.descEn,
    required this.descVi,
    required this.category,
    required this.slots,
    required this.builder,
    this.needsReading = false,
  });
  final String id, emoji, titleEn, titleVi, descEn, descVi;
  final SkillCategory category;
  final Set<SkillSlot> slots;

  /// Uses written word tiles (suggested off for children who don't read yet).
  final bool needsReading;

  /// The lesson screen. It must pop a [SkillOutcome].
  final Widget Function(SkillRequest req) builder;

  String title(Lang l) => l == Lang.vi ? titleVi : titleEn;
  String desc(Lang l) => l == Lang.vi ? descVi : descEn;
}

/// All skill modules available to games.
final skillModules = <SkillModule>[
  SkillModule(
    id: 'ask_treat',
    emoji: '🍓',
    titleEn: 'Choose & ask for a treat',
    titleVi: 'Chọn món & xin món',
    descEn: 'Picks a treat, builds the request ("Can I have an orange, please?") and is invited to say it.',
    descVi: 'Bé chọn món, ghép câu xin món ("Cho tôi xin quả cam ạ") và được mời nói to.',
    category: SkillCategory.communication,
    slots: {SkillSlot.afterLevel},
    needsReading: true,
    builder: (r) => TreatLessonScreen(request: r),
  ),
  SkillModule(
    id: 'ask_help',
    emoji: '🙋',
    titleEn: 'Ask for help / for more',
    titleVi: 'Xin giúp đỡ / xin thêm',
    descEn: 'Builds a polite request ("Can I have more moves, please?", "Please help me") and says it.',
    descVi: 'Ghép câu xin lễ phép ("Cho con thêm lượt ạ", "Giúp con với ạ") và nói to.',
    category: SkillCategory.communication,
    slots: {SkillSlot.outOfMoves, SkillSlot.afterLevel},
    needsReading: true,
    builder: (r) => BonusLessonScreen(
      task: BonusTask.request,
      seed: r.levelIndex * 7 + DateTime.now().millisecond,
      game: r.game,
      reward: r.reward,
    ),
  ),
  SkillModule(
    id: 'counting',
    emoji: '🔢',
    titleEn: 'Counting',
    titleVi: 'Đếm số',
    descEn: 'Counts 3–8 fruits and picks the right number. "Count with me" counts out loud.',
    descVi: 'Đếm 3–8 trái cây và chọn đúng số. Nút "Đếm cùng mình" đếm to cho bé nghe.',
    category: SkillCategory.math,
    slots: {SkillSlot.outOfMoves, SkillSlot.afterLevel},
    builder: (r) => BonusLessonScreen(
      task: BonusTask.count,
      seed: r.levelIndex * 13 + DateTime.now().millisecond,
      game: r.game,
      reward: r.reward,
    ),
  ),
];

/// Planned modules (shown to parents as "coming soon").
const upcomingSkills = <(String, String, String)>[
  ('😊', 'Feelings: name the emotion', 'Cảm xúc: gọi tên cảm xúc'),
  ('💰', 'Money: pick the right coins', 'Tiền: chọn đúng tiền'),
  (
    '📅',
    'Daily routine: put steps in order',
    'Việc hằng ngày: xếp đúng thứ tự',
  ),
];

SkillModule? moduleById(String id) {
  for (final m in skillModules) {
    if (m.id == id) return m;
  }
  return null;
}

/// What a game offers: its slots, which modules fit each slot, and the defaults.
class GameSkillSpec {
  const GameSkillSpec({
    required this.id,
    required this.emoji,
    required this.titleEn,
    required this.titleVi,
    required this.slots,
    required this.defaults,
  });
  final String id, emoji, titleEn, titleVi;
  final Map<SkillSlot, List<String>> slots;
  final Map<SkillSlot, List<String>> defaults;
  String title(Lang l) => l == Lang.vi ? titleVi : titleEn;
}

/// Games in the current app (each app overrides this in main()).
final gameSkillSpecsProvider = Provider<List<GameSkillSpec>>((ref) => const []);

/// Suggested lessons for this child: skip word-tile lessons if the child doesn't read yet.
Map<SkillSlot, List<String>> recommendSkills(
  GameSkillSpec spec,
  ChildProfile p,
) => {
  for (final MapEntry(key: slot, value: ids) in spec.slots.entries)
    slot: () {
      final fit = ids.where((id) {
        final m = moduleById(id);
        if (m == null) return false;
        if (m.needsReading && p.reading == Ability.notYet) return false;
        return true;
      }).toList();
      return fit.isEmpty
          ? [
              ids.firstWhere(
                (id) => !(moduleById(id)?.needsReading ?? true),
                orElse: () => ids.first,
              ),
            ]
          : fit;
    }(),
};

/// Picks and runs lessons according to the child's settings.
class SkillEngine {
  SkillEngine(this._ref);
  final Ref _ref;

  ChildProfile get _p => _ref.read(profileProvider);

  /// Enabled module ids for a game slot (parent settings, else the game's defaults).
  List<String> enabled(GameSkillSpec spec, SkillSlot slot) {
    final chosen =
        _p.skills[spec.id]?[slot.name] ?? spec.defaults[slot] ?? const [];
    final allowed = spec.slots[slot] ?? const [];
    return [
      for (final id in chosen)
        if (allowed.contains(id) && moduleById(id) != null) id,
    ];
  }

  bool hasLessons(GameSkillSpec spec, SkillSlot slot) =>
      enabled(spec, slot).isNotEmpty;

  /// Lesson after every Nth won level (parent setting; default every level).
  int afterEvery(GameSkillSpec spec) => _p.afterEvery[spec.id] ?? 1;

  bool dueAfterLevel(GameSkillSpec spec, int levelIndex) {
    final every = afterEvery(spec);
    return every > 0 &&
        levelIndex % every == 0 &&
        hasLessons(spec, SkillSlot.afterLevel);
  }

  /// The module that will run next for [slot] (without advancing).
  String? peek(GameSkillSpec spec, SkillSlot slot) {
    final ids = enabled(spec, slot);
    if (ids.isEmpty) return null;
    return ids[(_p.rotation['${spec.id}.${slot.name}'] ?? 0) % ids.length];
  }

  /// Runs the next enabled lesson for [slot]. Returns null if none is enabled or the child left.
  Future<SkillOutcome?> run(
    BuildContext context,
    GameSkillSpec spec,
    SkillRequest req,
  ) async {
    final ids = enabled(spec, req.slot);
    if (ids.isEmpty) return null;
    final key = '${spec.id}.${req.slot.name}';
    final i = _p.rotation[key] ?? 0;
    final module = moduleById(ids[i % ids.length])!;
    _ref.read(profileProvider.notifier).update((p) => p.rotation[key] = i + 1);
    final out = await Navigator.of(context)
        .push<SkillOutcome>(fadeRoute(module.builder(req)));
    if (out != null) {
      _ref
          .read(eventLogProvider)
          .log(
            'skill',
            game: spec.id,
            data: {
              'module': module.id,
              'slot': req.slot.name,
              'wrong': out.wrong,
              'hints': out.hints,
              'spoke': out.spoke,
            },
          );
    }
    return out;
  }
}

final skillEngineProvider = Provider<SkillEngine>((ref) => SkillEngine(ref));
