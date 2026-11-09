import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sk_core/l10n/app_localizations.dart';

import 'sing_say/sing_say.dart';

import 'package:snack_beats_game/snack_beats/snack_beats.dart';

/// Every game/tool registers here; the hub renders this list.
/// To add a game: create `lib/games/ID/`, use the core/ services, add a GameInfo below.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.emoji,
    required this.color,
    required this.title,
    this.launch,
  });
  final String id;
  final String emoji;
  final Color color;
  final String Function(AppLocalizations l) title;
  final void Function(BuildContext context, WidgetRef ref)? launch;
  bool get available => launch != null;
}

final games = <GameInfo>[
  GameInfo(
    id: SnackBeats.id,
    emoji: '🍓',
    color: const Color(0xFFFF1744),
    title: (l) => l.gameSnackBeats,
    launch: (context, ref) => SnackBeats.start(context, ref),
  ),
  GameInfo(
    id: SingSay.id,
    emoji: '🎤',
    color: const Color(0xFFFF1744),
    title: (l) => l.gameSing,
    launch: (context, ref) => SingSay.start(context, ref),
  ),
  GameInfo(
    id: 'cafe',
    emoji: '☕',
    color: const Color(0xFFFF6D00),
    title: (l) => l.gameCafe,
  ),
  GameInfo(
    id: 'kitchen',
    emoji: '🍳',
    color: const Color(0xFFFFD600),
    title: (l) => l.gameKitchen,
  ),
  GameInfo(
    id: 'my_day',
    emoji: '📅',
    color: const Color(0xFF00C853),
    title: (l) => l.gameMyDay,
  ),
  GameInfo(
    id: 'talk_board',
    emoji: '💬',
    color: const Color(0xFFAA00FF),
    title: (l) => l.gameTalk,
  ),
];
