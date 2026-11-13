import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/session/session_tracker.dart';
import 'package:sk_core/core/skills/skills.dart';
import 'package:sk_core/core/ui/effects.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/core/ui/widgets.dart';
import 'package:sk_core/l10n/app_localizations.dart';

import '../board/block_board_view.dart';
import '../board/block_game.dart';
import '../engine/grid.dart';
import '../engine/levels.dart';
import '../color_beats.dart';
import 'goal_chips.dart';
import 'reward_screen.dart';

enum _Result { none, win, stuck }

/// The block board. [level] null = calm mode (no goals; a full board makes space by itself).
class BlockPlayScreen extends ConsumerStatefulWidget {
  const BlockPlayScreen({super.key, required BlockLevel this.level});
  const BlockPlayScreen.calm({super.key}) : level = null;
  final BlockLevel? level;
  @override
  ConsumerState<BlockPlayScreen> createState() => _BlockPlayScreenState();
}

class _BlockPlayScreenState extends ConsumerState<BlockPlayScreen>
    with TracksPlayTime {
  late final BlockGame game;
  int linesLeft = 0;
  List<int> gemsLeft = const [];
  var result = _Result.none;
  bool _showCard = false;
  int _placed = 0;

  /// Best score in calm mode (kept on this device).
  static const _bestKey = 'color_beats.best';
  int _best = 0;

  BlockLevel? get level => widget.level;
  bool get calm => level == null;

  /// QA builds: --dart-define=SK_SEED=n makes the pieces repeatable.
  static const _qaSeed = int.fromEnvironment('SK_SEED');

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider);
    final lv = level;
    final soft = ref.read(profileProvider).effectsSoft;
    final rng = _qaSeed > 0 ? Random(_qaSeed) : Random();
    _best = ref.read(prefsProvider).getInt(_bestKey) ?? 0;
    if (lv == null) {
      final unlocked = ref.read(profileProvider).songs;
      audio.setSong(unlocked.isEmpty ? 0 : unlocked.last);
      ref.read(eventLogProvider).log('calm', game: ColorBeats.id);
    } else {
      startTracking(ref.read(sessionProvider));
      audio.setSong(lv.song);
      ref
          .read(eventLogProvider)
          .log('level_start', game: ColorBeats.id, data: {'level': lv.index});
      linesLeft = lv.lines;
      gemsLeft = [...lv.gems];
    }
    game = BlockGame(
      grid: lv?.newGrid() ?? Grid(),
      dealer: PieceDealer(tier: lv?.tier ?? 1, rng: rng),
      fxIntensity: soft || calm ? 0.4 : 1.0,
      idleHintMs: calm ? 20000 : 10000,
      onTap: () => audio.tap(_placed),
      onPlaced: _onPlaced,
      onStuck: _onStuck,
    );
  }

  void _onPlaced(PlaceResult r) {
    final audio = ref.read(audioProvider);
    _placed++;
    if (r.lines == 0) {
      audio.soft();
    } else {
      // Every cleared line plays the next note of the song; big clears add an octave and a chord.
      for (var i = 0; i < r.lines; i++) {
        Future.delayed(Duration(milliseconds: i * 140), () {
          if (mounted) audio.matchNote(big: r.lines >= 2, gentle: calm);
        });
      }
      if (r.combo >= 2 || r.lines >= 2) audio.chord();
      if (r.gems.isNotEmpty) audio.sparkle();
    }
    setState(() {
      if (calm) {
        if (game.grid.score > _best) {
          _best = game.grid.score;
          ref.read(prefsProvider).setInt(_bestKey, _best);
        }
        return;
      }
      linesLeft = max(0, linesLeft - r.lines);
      _collect(r.gems);
    });
    _checkWin();
  }

  void _collect(Map<int, int> gems) {
    for (final MapEntry(key: k, value: n) in gems.entries) {
      if (k < gemsLeft.length) gemsLeft[k] = max(0, gemsLeft[k] - n);
    }
  }

  int get _scoreLeft => max(0, (level?.score ?? 0) - game.grid.score);

  bool get _allDone =>
      linesLeft == 0 && gemsLeft.every((n) => n == 0) && _scoreLeft == 0;

  void _checkWin() {
    final lv = level;
    if (lv == null || result != _Result.none || !_allDone) return;
    result = _Result.win;
    game.lock();
    ref
        .read(eventLogProvider)
        .log(
          'level',
          game: ColorBeats.id,
          data: {'level': lv.index, 'result': 'win', 'score': game.grid.score},
        );
    ref.read(profileProvider.notifier).update((p) {
      p.stars += 3;
      p.gameLevels[ColorBeats.id] = max(
        p.gameLevels[ColorBeats.id] ?? 0,
        lv.index + 1,
      );
    });
    ref.read(audioProvider).winChime();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showCard = true);
    });
  }

  void _onStuck() {
    if (!mounted || result != _Result.none) return;
    if (calm) {
      // Calm mode never ends: make space and carry on.
      game.rescue();
      ref.read(audioProvider).sparkle();
      return;
    }
    result = _Result.stuck;
    ref
        .read(eventLogProvider)
        .log(
          'level',
          game: ColorBeats.id,
          data: {
            'level': level!.index,
            'result': 'retry',
            'score': game.grid.score,
          },
        );
    setState(() => _showCard = true);
  }

  static const _maxBonus = 3;
  int _bonusUsed = 0;

  SkillEngine get _skills => ref.read(skillEngineProvider);
  static const _spec = ColorBeats.skillSpec;

  bool get _canEarnSpace =>
      _bonusUsed < _maxBonus && _skills.hasLessons(_spec, SkillSlot.outOfMoves);

  /// Board full: a skill lesson chosen by the parent clears space instead of restarting.
  Future<void> _earnSpace() async {
    final lv = level!;
    final out = await _skills.run(
      context,
      _spec,
      SkillRequest(
        game: ColorBeats.id,
        slot: SkillSlot.outOfMoves,
        levelIndex: lv.index + _bonusUsed,
        reward: '🧱',
        rewardKind: SkillReward.blocks,
      ),
    );
    if (out == null || !mounted) return;
    ref
        .read(eventLogProvider)
        .log(
          'extra_moves',
          game: ColorBeats.id,
          data: {'level': lv.index, 'module': out.module, 'n': 3},
        );
    setState(() {
      _bonusUsed++;
      result = _Result.none;
      _showCard = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final r = game.rescue();
    setState(() => _collect(r.gems));
    ref.read(audioProvider).sparkle();
    _checkWin();
  }

  /// After a win: the next skill lesson (if due by the parent's settings), then the song reward.
  Future<void> _afterWin(BlockLevel lv) async {
    if (_skills.dueAfterLevel(_spec, lv.index)) {
      await _skills.run(
        context,
        _spec,
        SkillRequest(
          game: ColorBeats.id,
          slot: SkillSlot.afterLevel,
          levelIndex: lv.index,
        ),
      );
      if (!mounted) return;
    }
    Navigator.of(context)
        .pushReplacement(fadeRoute(BlockRewardScreen(level: lv)));
  }

  /// Restart the level. Asks first so a stray tap doesn't lose the game.
  Future<void> _confirmRestart() async {
    if (result != _Result.none) return;
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '↻',
                style: TextStyle(fontSize: 56, color: AppColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                l.restartTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  BigButton(
                    label: l.restartNo,
                    light: true,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  BigButton(
                    label: l.restartYes,
                    primary: true,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (yes != true || !mounted || result != _Result.none) return;
    final lv = level;
    if (lv != null) {
      ref
          .read(eventLogProvider)
          .log('restart', game: ColorBeats.id, data: {'level': lv.index});
    }
    _replay();
  }

  void _replay() {
    final lv = level;
    Navigator.of(context).pushReplacement(
      fadeRoute(
        lv == null ? const BlockPlayScreen.calm() : BlockPlayScreen(level: lv),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context);
    game.praise = [
      l.praiseNice,
      l.praiseGreat,
      l.praiseAwesome,
      l.praiseAmazing,
    ];
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lv = level;
    return AppScreen(
      colors: calm ? const [Color(0xFFB2EBF2), Color(0xFFE0F7FA)] : null,
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  HomeBtn(
                    onBeforeLeave: () {
                      if (!calm && result == _Result.none) {
                        ref
                            .read(eventLogProvider)
                            .log(
                              'quit',
                              game: ColorBeats.id,
                              data: {'level': lv!.index},
                            );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: '↻',
                    semantic: l.restartYes,
                    onPressed: _confirmRestart,
                  ),
                  Expanded(child: Center(child: _scoreBox(l))),
                  // Balances the two buttons on the left so the score is centred.
                  const SizedBox(width: 120),
                ],
              ),
              const SizedBox(height: 10),
              if (calm)
                Text(
                  '🌙 ${l.calmTitle}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                GoalChips(
                  items: goalItems(
                    lv!,
                    linesLeft: linesLeft,
                    gemsLeft: gemsLeft,
                    scoreLeft: _scoreLeft,
                  ),
                ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: BlockBoardView(game: game),
                  ),
                ),
              ),
            ],
          ),
          if (_showCard) _resultCard(l),
          if (_showCard &&
              result == _Result.win &&
              !ref.read(profileProvider).effectsSoft)
            const Positioned.fill(child: Confetti()),
        ],
      ),
    );
  }

  Widget _scoreBox(AppLocalizations l) => Container(
    constraints: const BoxConstraints(minWidth: 84),
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.glass2,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          calm ? '👑 $_best' : l.tbScore,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        BounceOnChange(
          value: game.grid.score,
          child: Text(
            '${game.grid.score}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _resultCard(AppLocalizations l) {
    final win = result == _Result.win;
    final lv = level!;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x990A0E28),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(28),
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(win ? '🤩' : '🧱', style: const TextStyle(fontSize: 84)),
                const SizedBox(height: 8),
                Text(
                  win ? l.tbLevelDone : l.tbBoardFull,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (!win && _canEarnSpace) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.tbNewBlocksNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: win
                      ? [
                          BigButton(
                            label: l.nextArrow,
                            primary: true,
                            onPressed: () => _afterWin(lv),
                          ),
                        ]
                      : [
                          if (_canEarnSpace)
                            BigButton(
                              label: l.tbNewBlocks,
                              primary: true,
                              big: true,
                              onPressed: _earnSpace,
                            ),
                          BigButton(
                            label: l.home,
                            light: true,
                            onPressed: () =>
                                Navigator.of(context)
                                    .popUntil((r) => r.isFirst),
                          ),
                          BigButton(
                            label: l.tryAgain,
                            primary: !_canEarnSpace,
                            light: _canEarnSpace,
                            onPressed: _replay,
                          ),
                        ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
