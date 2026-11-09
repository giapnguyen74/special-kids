import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/content/songs.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/session/session_tracker.dart';
import 'package:sk_core/core/ui/effects.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/core/ui/widgets.dart';
import 'package:sk_core/l10n/app_localizations.dart';

import '../levels.dart';
import '../snack_beats.dart';

/// Unlocks the level's song into the shared music collection and plays it.
class RewardScreen extends ConsumerStatefulWidget {
  const RewardScreen({super.key, required this.level});
  final SnackLevel level;
  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen>
    with TracksPlayTime {
  late final bool isNew = !ref
      .read(profileProvider)
      .songs
      .contains(widget.level.song);
  late final AudioService _audio = ref.read(audioProvider);

  @override
  void initState() {
    super.initState();
    startTracking(ref.read(sessionProvider));
    if (isNew) {
      Future.microtask(
        () => ref
            .read(profileProvider.notifier)
            .update((p) => p.songs.add(widget.level.song)),
      );
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _audio.playSong(widget.level.song);
    });
  }

  @override
  void dispose() {
    _audio.stopSong();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = ref.watch(profileProvider.select((p) => p.lang));
    return AppScreen(
      child: Stack(
        children: [
          if (!ref.read(profileProvider).effectsSoft)
            const Positioned.fill(child: Confetti(count: 120)),
          Column(
            children: [
              const Row(children: [HomeBtn(), Spacer(), StarsPill()]),
              const Spacer(),
              const Bob(child: Text('🎶', style: TextStyle(fontSize: 84))),
              const SizedBox(height: 12),
              Text(
                isNew ? l.newSong : l.greatJob,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '🎵 ${songs[widget.level.song].title(lang)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 30),
              BigButton(
                label: l.nextLevel,
                primary: true,
                big: true,
                onPressed: () => SnackBeats.start(context, ref, replace: true),
              ),
              const SizedBox(height: 16),
              BigButton(
                label: l.home,
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }
}
