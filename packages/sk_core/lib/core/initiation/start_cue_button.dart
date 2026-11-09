import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../audio/audio_service.dart';
import '../progress/event_log.dart';
import '../progress/profile.dart';
import '../ui/widgets.dart';

/// INITIATION TRAINING — used for every "start" moment in every game.
///
/// The app never auto-advances; it waits for the child.
/// - Tap before the glow appears  -> "self-start": +1 star, and next time the cue waits longer (help fades).
/// - Needed the glow              -> next time the cue comes a little sooner.
/// - Very long wait               -> a pointing hand appears (strongest hint).
/// Every start is logged (latency, self-start, hand) for the parent dashboard.
class StartCueButton extends ConsumerStatefulWidget {
  const StartCueButton({
    super.key,
    required this.label,
    required this.cueContext,
    required this.onStart,
    this.subtitle,
    this.game,
  });

  final String label;
  final String? subtitle;
  final String cueContext; // e.g. 'hub', 'level'
  final String? game;
  final VoidCallback onStart;

  @override
  ConsumerState<StartCueButton> createState() => _StartCueButtonState();
}

class _StartCueButtonState extends ConsumerState<StartCueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final _shownAt = Stopwatch()..start();
  late final int _delay = ref.read(profileProvider).cueDelayMs;
  Timer? _cueTimer, _handTimer;
  bool _cue = false, _hand = false, _done = false;

  @override
  void initState() {
    super.initState();
    _cueTimer = Timer(Duration(milliseconds: _delay), () {
      if (!mounted) return;
      setState(() => _cue = true);
      _pulse.repeat(reverse: true);
    });
    _handTimer = Timer(Duration(milliseconds: _delay * 2 + 6000), () {
      if (mounted) setState(() => _hand = true);
    });
  }

  @override
  void dispose() {
    _cueTimer?.cancel();
    _handTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _tap() {
    if (_done) return;
    _done = true;
    final latency = _shownAt.elapsedMilliseconds;
    final selfStart = latency < _delay;
    ref.read(profileProvider.notifier).update((p) {
      if (selfStart) {
        p.stars += 1;
        p.cueDelayMs = min(15000, p.cueDelayMs + 1000);
      } else {
        p.cueDelayMs = max(2000, p.cueDelayMs - 250);
      }
    });
    ref
        .read(eventLogProvider)
        .log(
          'start',
          game: widget.game,
          data: {
            'context': widget.cueContext,
            'latency': latency,
            'selfStart': selfStart,
            'hand': _hand,
          },
        );
    if (selfStart) {
      showToast(context, AppLocalizations.of(context).selfStart);
      ref.read(audioProvider).sparkle();
    } else {
      ref.read(audioProvider).tap(4);
    }
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => BigButton(
        label: widget.label,
        subtitle: widget.subtitle,
        primary: true,
        big: true,
        glow: _cue ? Curves.easeInOut.transform(_pulse.value) : 0,
        showHand: _hand,
        onPressed: _tap,
      ),
    );
  }
}
