import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/skills/skills.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/session/session_tracker.dart';
import 'package:sk_core/core/ui/effects.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/core/ui/widgets.dart';
import 'package:sk_core/l10n/app_localizations.dart';

import '../board/match3_game.dart';
import '../levels.dart';
import '../snack_beats.dart';
import 'goal_chips.dart';
import 'reward_screen.dart';

enum _Result { none, win, lose }

/// The match-3 board. [level] null = calm mode (no goals, no moves, gentle sound).
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required SnackLevel this.level});
  const PlayScreen.calm({super.key}) : level = null;
  final SnackLevel? level;
  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> with TracksPlayTime {
  late final Match3Game game;
  late final List<int> left;
  late int moves;
  int iceLeft = 0, wallsLeft = 0, mudLeft = 0;
  var result = _Result.none;
  bool _showCard = false;

  SnackLevel? get level => widget.level;
  bool get calm => level == null;

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider);
    final lv = level;
    if (lv == null) {
      final unlocked = ref.read(profileProvider).songs;
      audio.setSong(unlocked.isEmpty ? 0 : unlocked.last);
      ref.read(eventLogProvider).log('calm', game: SnackBeats.id);
      left = const [];
      moves = 0;
      game = Match3Game(
        types: const [0, 1, 2, 3, 4, 5],
        fxIntensity: 0.4,
        speed: 1.4,
        idleHintMs: 15000,
        onClear: (_, _, _) => audio.matchNote(gentle: true),
      );
      return;
    }
    startTracking(ref.read(sessionProvider));
    audio.setSong(lv.song);
    ref
        .read(eventLogProvider)
        .log('level_start', game: SnackBeats.id, data: {'level': lv.index});
    left = [for (final g in lv.goals) g.n];
    moves = lv.moves;
    final soft = ref.read(profileProvider).effectsSoft;
    iceLeft = lv.ice;
    wallsLeft = lv.walls;
    mudLeft = lv.mud;
    game = Match3Game(
      types: lv.types,
      layout: lv.layout,
      fxIntensity: soft ? 0.4 : 1.0,
      onClear: (counts, step, info) {
        audio.matchNote(
          big: info.size >= 5 || info.specials > 0 || info.created > 0,
        );
        if (info.specials > 0) audio.chord();
        setState(() {
          for (var i = 0; i < lv.goals.length; i++) {
            left[i] = max(0, left[i] - (counts[lv.goals[i].food] ?? 0));
          }
          _readObstacles();
        });
        game.preferTypes = _neededFoods(lv);
      },
      onSwap: () => setState(() => moves--),
      onInvalid: audio.soft,
      onSettled: () {
        setState(_readObstacles); // mud may have spread
        _checkEnd();
      },
    );
    game.preferTypes = _neededFoods(lv);
  }

  void _readObstacles() {
    iceLeft = game.board.iceLeft;
    wallsLeft = game.board.wallsLeft;
    mudLeft = game.board.mudLeft;
  }

  /// Restart the level (new board, full moves). Asks first so a stray tap doesn't lose the game.
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
          .log(
            'restart',
            game: SnackBeats.id,
            data: {'level': lv.index, 'movesUsed': lv.moves - moves},
          );
    }
    Navigator.of(context).pushReplacement(
      fadeRoute(lv == null ? const PlayScreen.calm() : PlayScreen(level: lv)),
    );
  }

  static const _maxBonus = 2;
  static const _bonusMoves = 5;
  int _bonusUsed = 0;

  SkillEngine get _skills => ref.read(skillEngineProvider);
  static const _spec = SnackBeats.skillSpec;

  bool get _canEarnMoves =>
      _bonusUsed < _maxBonus && _skills.hasLessons(_spec, SkillSlot.outOfMoves);

  /// Out of moves: a skill lesson chosen by the parent's settings earns +5 moves instead of restarting.
  Future<void> _earnExtraMoves() async {
    final lv = level!;
    final out = await _skills.run(
      context,
      _spec,
      SkillRequest(
        game: SnackBeats.id,
        slot: SkillSlot.outOfMoves,
        levelIndex: lv.index + _bonusUsed,
        reward: '+$_bonusMoves',
      ),
    );
    if (out == null || !mounted) return;
    ref
        .read(eventLogProvider)
        .log(
          'extra_moves',
          game: SnackBeats.id,
          data: {'level': lv.index, 'module': out.module, 'n': _bonusMoves},
        );
    setState(() {
      _bonusUsed++;
      moves += _bonusMoves;
      result = _Result.none;
      _showCard = false;
    });
    game.unlock();
    ref.read(audioProvider).sparkle();
  }

  /// After a win: the next skill lesson (if due by the parent's settings), then the song reward.
  Future<void> _afterWin(SnackLevel lv) async {
    if (_skills.dueAfterLevel(_spec, lv.index)) {
      await _skills.run(
        context,
        _spec,
        SkillRequest(
          game: SnackBeats.id,
          slot: SkillSlot.afterLevel,
          levelIndex: lv.index,
          suggestedFood: lv.goals.isNotEmpty ? lv.goals.first.food : null,
          customer: lv.customer,
        ),
      );
      if (!mounted) return; // the child went Home from inside the lesson
    }
    Navigator.of(context).pushReplacement(fadeRoute(RewardScreen(level: lv)));
  }

  bool get _allDone =>
      left.every((n) => n == 0) &&
      iceLeft == 0 &&
      wallsLeft == 0 &&
      mudLeft == 0;

  /// Foods still needed for the order: rockets aim at these.
  Set<int> _neededFoods(SnackLevel lv) => {
    for (var i = 0; i < lv.goals.length; i++)
      if (left[i] > 0) lv.goals[i].food,
  };

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
    game.destroy();
    super.dispose();
  }

  void _checkEnd() {
    final lv = level!;
    if (result != _Result.none || !mounted) return;
    if (_allDone) {
      result = _Result.win;
      game.lock();
      ref
          .read(eventLogProvider)
          .log(
            'level',
            game: SnackBeats.id,
            data: {'level': lv.index, 'result': 'win', 'movesLeft': moves},
          );
      ref.read(profileProvider.notifier).update((p) {
        p.stars += 3;
        p.gameLevels[SnackBeats.id] = max(
          p.gameLevels[SnackBeats.id] ?? 0,
          lv.index + 1,
        );
      });
      ref.read(audioProvider).winChime();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showCard = true);
      });
    } else if (moves <= 0) {
      // No lives, no penalty: just a calm retry.
      result = _Result.lose;
      game.lock();
      ref
          .read(eventLogProvider)
          .log(
            'level',
            game: SnackBeats.id,
            data: {'level': lv.index, 'result': 'retry'},
          );
      setState(() => _showCard = true);
    }
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
                              game: SnackBeats.id,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: calm
                        ? Text(
                            '🌙 ${l.calmTitle}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : GoalChips(
                            items: goalItems(
                              lv!,
                              foodsLeft: left,
                              ice: iceLeft,
                              walls: wallsLeft,
                              mud: mudLeft,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  if (!calm)
                    Container(
                      width: 76,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.glass2,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            l.moves,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            '$moves',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: moves <= 3
                                  ? const Color(0xFFD50000)
                                  : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 56),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 620,
                      maxHeight: 620,
                    ),
                    child: Match3BoardView(game: game),
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
                Text(win ? '😋' : '🙂', style: const TextStyle(fontSize: 84)),
                const SizedBox(height: 8),
                Text(
                  win ? l.orderDone : l.almost,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (!win && _canEarnMoves) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.extraMovesNote,
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
                            // "Serve the order" when the next lesson is the treat request.
                            label:
                                _skills.dueAfterLevel(_spec, lv.index) &&
                                    _skills.peek(_spec, SkillSlot.afterLevel) ==
                                        'ask_treat'
                                ? l.serve
                                : l.nextArrow,
                            primary: true,
                            onPressed: () => _afterWin(lv),
                          ),
                        ]
                      : [
                          if (_canEarnMoves)
                            BigButton(
                              label: l.extraMoves,
                              primary: true,
                              big: true,
                              onPressed: _earnExtraMoves,
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
                            primary: !_canEarnMoves,
                            light: _canEarnMoves,
                            onPressed: () => Navigator.of(
                              context,
                            ).pushReplacement(fadeRoute(PlayScreen(level: lv))),
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
