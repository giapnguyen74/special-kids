import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../audio/audio_service.dart';
import '../content/foods.dart';
import '../content/lang.dart';
import '../progress/event_log.dart';
import '../progress/profile.dart';
import '../sentence/sentence_builder.dart';
import '../skills/skills.dart';
import '../speech/speech_service.dart';
import '../ui/effects.dart';
import '../ui/palette.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// A short skill task the child does to earn a reward (e.g. extra moves).
enum BonusTask { request, count }

class BonusResult {
  BonusResult(
    this.task, {
    required this.wrong,
    required this.hints,
    this.spoke = false,
  });
  final BonusTask task;
  final int wrong, hints;
  final bool spoke;
}

/// Requests the child can use in real life ("Can I have more moves, please?").
const _requests = <Lang, List<List<String>>>{
  Lang.en: [
    ['Can', 'I', 'have', 'more', 'moves', 'please'],
    ['I', 'need', 'more', 'moves', 'please'],
    ['Please', 'help', 'me'],
  ],
  Lang.vi: [
    ['Cho', 'con', 'thêm', 'lượt', 'ạ'],
    ['Con', 'cần', 'thêm', 'lượt', 'chơi', 'ạ'],
    ['Giúp', 'con', 'với', 'ạ'],
  ],
};

/// Same requests when the reward is new blocks (Color Beats: the board is full).
const _blockRequests = <Lang, List<List<String>>>{
  Lang.en: [
    ['Can', 'I', 'have', 'more', 'blocks', 'please'],
    ['I', 'need', 'more', 'space', 'please'],
    ['Please', 'help', 'me'],
  ],
  Lang.vi: [
    ['Cho', 'con', 'thêm', 'gạch', 'ạ'],
    ['Con', 'cần', 'thêm', 'chỗ', 'ạ'],
    ['Giúp', 'con', 'với', 'ạ'],
  ],
};

const _distractors = {Lang.en: 'go', Lang.vi: 'đi'};

/// Full-screen mini lesson (skill modules "ask_help" and "counting"). Pops a [SkillOutcome] when done (never fails: errorless help).
/// [game] is used for logging; [seed] varies the content.
class BonusLessonScreen extends ConsumerStatefulWidget {
  const BonusLessonScreen({
    super.key,
    required this.task,
    required this.seed,
    this.game,
    this.reward = '+5',
    this.rewardKind = SkillReward.moves,
  });
  final BonusTask task;
  final int seed;
  final String? game;

  /// What the child earns, shown in the title (e.g. "+5").
  final String reward;
  final SkillReward rewardKind;

  @override
  ConsumerState<BonusLessonScreen> createState() => _BonusLessonScreenState();
}

class _BonusLessonScreenState extends ConsumerState<BonusLessonScreen> {
  late final Lang lang = ref.read(profileProvider).lang;
  late final Random rng = Random(widget.seed);
  bool get vi => lang == Lang.vi;
  String t(String en, String v) => vi ? v : en;

  // request
  late final List<List<String>> _pool =
      (widget.rewardKind == SkillReward.blocks ? _blockRequests : _requests)[lang]!;
  late final List<String> words = _pool[widget.seed % _pool.length];
  SentenceResult? _built;

  // count
  late final int countFood = rng.nextInt(foods.length);
  late final int countN = 3 + rng.nextInt(6); // 3..8
  late final List<int> options = () {
    final s = <int>{countN};
    while (s.length < 3) {
      final d = countN + rng.nextInt(5) - 2;
      if (d >= 1 && d <= 10) s.add(d);
    }
    return s.toList()..shuffle(rng);
  }();
  int _countWrong = 0;
  int? _shake;
  bool _countDone = false;

  String get _prompt => widget.task == BonusTask.request
      ? (widget.rewardKind == SkillReward.blocks
            ? t(
                'Want more space and new blocks? Ask nicely!',
                'Muốn thêm chỗ và gạch mới? Hãy xin thật lễ phép nhé!',
              )
            : t(
                'Want ${widget.reward} moves? Ask nicely!',
                'Muốn thêm ${widget.reward} lượt? Hãy xin thật lễ phép nhé!',
              ))
      : t(
          'How many ${foods[countFood].words(lang).plural}?',
          'Có bao nhiêu ${foods[countFood].vi.count}?',
        );

  String get _sentence {
    final s = words.join(' ');
    final end = (words.first == 'Can' || words.first == 'Cho')
        ? (vi ? '.' : '?')
        : '.';
    return '${s[0].toUpperCase()}${s.substring(1)}$end';
  }

  void _speak(String s) => ref.read(speechProvider).speak(s, lang);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _speak(_prompt);
      if (widget.task == BonusTask.request &&
          ref.read(profileProvider).hintFor(lang) == 0) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted && _built == null) _speak(_sentence);
        });
      }
    });
  }

  void _finish(BonusResult r) {
    final log = ref.read(eventLogProvider);
    log.log(
      'bonus',
      game: widget.game,
      data: {
        'task': r.task.name,
        'wrong': r.wrong,
        'hints': r.hints,
        'spoke': r.spoke,
      },
    );
    if (r.task == BonusTask.request) {
      // Counts toward the sentence / speaking skills too.
      log.log(
        'sentence',
        game: widget.game,
        data: {
          'lang': lang.name,
          'words': words.length,
          'wrong': r.wrong,
          'hints': r.hints,
          'spoke': r.spoke,
          'source': 'bonus',
        },
      );
    } else {
      log.log(
        'count',
        game: widget.game,
        data: {'n': countN, 'wrong': r.wrong},
      );
    }
    ref
        .read(profileProvider.notifier)
        .update((p) => p.stars += r.spoke ? 2 : 1);
    Navigator.of(context).pop(
      SkillOutcome(
        r.task == BonusTask.count ? 'counting' : 'ask_help',
        wrong: r.wrong,
        hints: r.hints,
        spoke: r.spoke,
      ),
    );
  }

  void _tapNumber(int n) {
    if (_countDone) return;
    if (n == countN) {
      setState(() => _countDone = true);
      ref.read(audioProvider).sparkle();
      _speak(t('Yes! $countN!', 'Đúng rồi! $countN!'));
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          _finish(
            BonusResult(
              BonusTask.count,
              wrong: _countWrong,
              hints: _countWrong > 0 ? 1 : 0,
            ),
          );
        }
      });
    } else {
      ref.read(audioProvider).soft();
      setState(() {
        _countWrong++;
        _shake = n;
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _shake = null);
      });
    }
  }

  void _countAloud() {
    _speak([for (var i = 1; i <= countN; i++) '$i'].join(', '));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppScreen(
      scroll: true,
      child: Stack(
        children: [
          if (_countDone) const Positioned.fill(child: Confetti(count: 60)),
          Column(
            children: [
              Row(
                children: [
                  Pill(
                    color: Pure.yellow,
                    child: Text(
                      '🎁 ${widget.reward}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const StarsPill(),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.task == BonusTask.request ? '🙋' : '🔢',
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 10),
              SpeechBubble(text: _prompt, onSpeak: () => _speak(_prompt)),
              const SizedBox(height: 20),
              if (widget.task == BonusTask.request)
                ..._request(l)
              else
                ..._count(),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _request(AppLocalizations l) => [
    SentenceBuilder(
      words: words,
      distractor: _distractors[lang],
      hintLevel: ref.read(profileProvider).hintFor(lang),
      onWordPlaced: (w, i) {
        ref.read(audioProvider).tap(i + 1);
        if (i < words.length - 1) _speak(w);
      },
      onWrong: ref.read(audioProvider).soft,
      onDone: (r) {
        setState(() => _built = r);
        _speak(_sentence);
      },
    ),
    if (_built != null) ...[
      const SizedBox(height: 12),
      Text(
        _sentence,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2962FF),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l.sayIt,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          BigButton(
            label: l.saidIt,
            primary: true,
            onPressed: () => _finish(
              BonusResult(
                BonusTask.request,
                wrong: _built!.wrong,
                hints: _built!.hints,
                spoke: true,
              ),
            ),
          ),
          BigButton(
            label: l.skip,
            onPressed: () => _finish(
              BonusResult(
                BonusTask.request,
                wrong: _built!.wrong,
                hints: _built!.hints,
              ),
            ),
          ),
        ],
      ),
    ],
  ];

  List<Widget> _count() => [
    Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < countN; i++)
                Text(
                  foods[countFood].emoji,
                  style: const TextStyle(fontSize: 48),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _countAloud,
            icon: const Text('🔊', style: TextStyle(fontSize: 20)),
            label: Text(
              t('Count with me', 'Đếm cùng mình'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    Wrap(
      spacing: 16,
      alignment: WrapAlignment.center,
      children: [
        for (final n in options)
          TweenAnimationBuilder<double>(
            key: ValueKey('n$n-${_shake == n}'),
            tween: Tween(begin: 0, end: _shake == n ? 1 : 0),
            duration: const Duration(milliseconds: 350),
            builder: (_, v, child) => Transform.translate(
              offset: Offset(
                _shake == n ? 8 * (v < .5 ? -1 : 1) * (1 - v) : 0,
                0,
              ),
              child: child,
            ),
            child: GestureDetector(
              onTap: () => _tapNumber(n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 90,
                height: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _countDone && n == countN ? Pure.green : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    const BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                    // Errorless: after one mistake the right answer glows.
                    if (_countWrong > 0 && !_countDone && n == countN)
                      BoxShadow(
                        color: Pure.yellow.withValues(alpha: 0.9),
                        blurRadius: 26,
                        spreadRadius: 8,
                      ),
                  ],
                ),
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: _countDone && n == countN
                        ? Colors.white
                        : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  ];
}
