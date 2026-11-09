import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/core/initiation/start_cue_button.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/rewards/music_room_screen.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/core/ui/widgets.dart';

import '../games/game_registry.dart';

import 'package:snack_beats_game/snack_beats/snack_beats.dart';
import 'package:sk_core/l10n/app_localizations.dart';
import 'package:sk_core/parents/demo_data.dart';
import 'package:sk_core/parents/parent_dashboard_screen.dart';

/// Home: the main game (with start cue), music, calm mode, upcoming games, parent area.
class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});
  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> with RouteAware {
  int _cueKey = 0; // bump to re-arm the start cue when the child returns here

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
    ref.read(eventLogProvider).log('app_open');
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
    final main = games.first;

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
                const SizedBox(height: 16),
                const Bob(
                  child: Text('🍓🎵🍊', style: TextStyle(fontSize: 60)),
                ),
                TitleText(main.title(l), size: 52),
                Text(
                  l.gameSnackBeatsDesc,
                  style: const TextStyle(fontSize: 20, color: AppColors.muted),
                ),
                const SizedBox(height: 32),
                StartCueButton(
                  key: ValueKey(_cueKey),
                  label: l.play,
                  subtitle: l.levelN(level + 1),
                  cueContext: 'hub',
                  game: main.id,
                  onStart: () => main.launch!(context, ref),
                ),
                const SizedBox(height: 28),
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
                const SizedBox(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final g in games.skip(1).where((g) => g.available))
                      _GameCard(game: g, onTap: () => g.launch!(context, ref)),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final g in games.where((g) => !g.available))
                      _ComingSoonCard(game: g),
                  ],
                ),
                const SizedBox(height: 28),
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

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.game});
  final GameInfo game;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Opacity(
      opacity: .7,
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: game.color.withValues(alpha: .5), width: 2),
        ),
        child: Column(
          children: [
            Text(game.emoji, style: const TextStyle(fontSize: 34)),
            Text(
              game.title(l),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              l.comingSoon,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bright card for a playable game.
class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});
  final GameInfo game;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: game.title(l),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                game.color,
                Color.lerp(game.color, const Color(0xFFAA00FF), 0.6)!,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: game.color.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Bob(
                amount: 5,
                child: Text(game.emoji, style: const TextStyle(fontSize: 46)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title(l),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (game.id == 'sing_say')
                      Text(
                        l.gameSingDesc,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              const Text(
                '▶',
                style: TextStyle(fontSize: 26, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
