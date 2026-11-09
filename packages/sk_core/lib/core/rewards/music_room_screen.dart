import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../audio/audio_service.dart';
import '../content/songs.dart';
import '../progress/event_log.dart';
import '../progress/profile.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The shared music collection: songs unlocked in any game. Choosing music = self-initiated leisure.
class MusicRoomScreen extends ConsumerStatefulWidget {
  const MusicRoomScreen({super.key});
  @override
  ConsumerState<MusicRoomScreen> createState() => _MusicRoomScreenState();
}

class _MusicRoomScreenState extends ConsumerState<MusicRoomScreen> {
  int? _playing;
  late final AudioService _audio = ref.read(audioProvider);

  @override
  void dispose() {
    _audio.stopSong();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = ref.watch(profileProvider);
    return AppScreen(
      child: Column(
        children: [
          Row(
            children: [
              const HomeBtn(),
              Expanded(
                child: Text(
                  l.myMusic,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 56),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.separated(
                itemCount: songs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final unlocked = p.songs.contains(i);
                  final playing = _playing == i;
                  return Opacity(
                    opacity: unlocked ? 1 : .45,
                    child: GestureDetector(
                      onTap: !unlocked
                          ? null
                          : () {
                              _audio.playSong(i);
                              setState(() => _playing = i);
                              ref
                                  .read(eventLogProvider)
                                  .log('music', data: {'song': i});
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: playing ? AppColors.accent : AppColors.glass2,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Text(
                              unlocked ? '🎵' : '🔒',
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                unlocked ? songs[i].title(p.lang) : l.locked,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: playing
                                      ? AppColors.accentInk
                                      : AppColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
