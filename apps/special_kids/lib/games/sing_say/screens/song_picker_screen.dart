import 'package:flutter/material.dart';
import 'package:sk_core/core/ui/palette.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/core/audio/audio_service.dart';
import 'package:sk_core/core/progress/event_log.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/core/ui/widgets.dart';
import 'package:sk_core/l10n/app_localizations.dart';

import '../sing_say.dart';
import '../sing_songs.dart';
import 'sing_screen.dart';

/// The child CHOOSES a song (choosing = initiating). The time to choose is logged.
class SongPickerScreen extends ConsumerStatefulWidget {
  const SongPickerScreen({super.key});
  @override
  ConsumerState<SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends ConsumerState<SongPickerScreen> {
  final _watch = Stopwatch()..start();

  static const _cardColors = [Pure.red, Pure.orange, Pure.green, Pure.purple];

  void _pick(SingSong song) {
    ref.read(audioProvider).tap(4);
    ref
        .read(eventLogProvider)
        .log(
          'sing_pick',
          game: SingSay.id,
          data: {'song': song.id, 'latency': _watch.elapsedMilliseconds},
        );
    Navigator.of(context).push(fadeRoute(SingScreen(song: song)));
    _watch.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = ref.watch(profileProvider.select((p) => p.lang));
    return AppScreen(
      child: Column(
        children: [
          Row(
            children: [
              const HomeBtn(),
              Expanded(
                child: Text(
                  l.chooseSong,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const StarsPill(),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < singSongs.length; i++)
                      _SongCard(
                        song: singSongs[i],
                        color: _cardColors[i % _cardColors.length],
                        title: singSongs[i].title[lang]!,
                        preview: singSongs[i].parsed(lang).first.text,
                        onTap: () => _pick(singSongs[i]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({
    required this.song,
    required this.color,
    required this.title,
    required this.preview,
    required this.onTap,
  });
  final SingSong song;
  final Color color;
  final String title, preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: title,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.35)!, color],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Bob(
              amount: 5,
              child: Text(song.emoji, style: const TextStyle(fontSize: 60)),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '“$preview”',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}
