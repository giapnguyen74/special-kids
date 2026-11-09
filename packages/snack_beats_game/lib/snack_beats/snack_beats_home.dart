import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_core/core/initiation/start_cue_button.dart';
import 'package:sk_core/core/lessons/bonus_lesson_screen.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/rewards/music_room_screen.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/core/ui/widgets.dart';
import 'package:sk_core/l10n/app_localizations.dart';
import 'package:sk_core/parents/demo_data.dart';
import 'package:sk_core/parents/parent_dashboard_screen.dart';

import 'snack_beats.dart';

/// Home screen of the standalone Snack Beats app:
/// Play (with start cue), My Music, Calm Mode, parent area (press and hold).
class SnackBeatsHome extends ConsumerStatefulWidget {
  const SnackBeatsHome({super.key});
  @override
  ConsumerState<SnackBeatsHome> createState() => _SnackBeatsHomeState();
}

class _SnackBeatsHomeState extends ConsumerState<SnackBeatsHome>
    with RouteAware {
  int _cueKey =
      0; // bump to re-arm the start cue when the child comes back here

  @override
  void initState() {
    super.initState();
    // QA/demo builds only: --dart-define=SK_DEMO=true fills two weeks of sample play.
    if (const bool.fromEnvironment('SK_DEMO') &&
        ref.read(eventLogProvider).events.length < 5) {
      seedDemoData(
        ref.read(eventLogProvider),
        ref.read(profileProvider.notifier),
      );
    }
    ref.read(eventLogProvider).log('app_open', game: SnackBeats.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => setState(() => _cueKey++);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final level = ref.watch(
      profileProvider.select((p) => p.gameLevels[SnackBeats.id] ?? 0),
    );
    return AppScreen(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              children: [
                const Row(
                  children: [
                    ChildPill(),
                    SizedBox(width: 8),
                    StarsPill(),
                    Spacer(),
                    LangToggle(),
                  ],
                ),
                const SizedBox(height: 24),
                const Bob(
                  child: Text('🍓🎵🍊', style: TextStyle(fontSize: 70)),
                ),
                TitleText(l.gameSnackBeats, size: 56),
                Text(
                  l.gameSnackBeatsDesc,
                  style: const TextStyle(fontSize: 20, color: AppColors.muted),
                ),
                const SizedBox(height: 40),
                StartCueButton(
                  key: ValueKey(_cueKey),
                  label: l.play,
                  subtitle: l.levelN(level + 1),
                  cueContext: 'hub',
                  game: SnackBeats.id,
                  onStart: () {
                    // QA only: --dart-define=SK_BONUS=request|count opens a bonus lesson directly.
                    const qaBonus = String.fromEnvironment('SK_BONUS');
                    if (qaBonus.isNotEmpty) {
                      Navigator.of(context).push(
                        fadeRoute(
                          BonusLessonScreen(
                            task: qaBonus == 'count'
                                ? BonusTask.count
                                : BonusTask.request,
                            seed: 1,
                          ),
                        ),
                      );
                      return;
                    }
                    SnackBeats.start(context, ref);
                  },
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    BigButton(
                      label: '🎵 ${l.myMusic}',
                      onPressed: () =>
                          Navigator.of(context)
                              .push(fadeRoute(const MusicRoomScreen())),
                    ),
                    BigButton(
                      label: '🌙 ${l.calm}',
                      onPressed: () => SnackBeats.startCalm(context),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                HoldButton(
                  label: '👪 ${l.parentsHold}',
                  onComplete: () =>
                      Navigator.of(context)
                          .push(fadeRoute(const ParentDashboardScreen())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
