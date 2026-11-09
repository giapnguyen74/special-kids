import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../progress/event_log.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'session_tracker.dart';

/// Gentle break screen shown between levels when the session limit is reached.
/// Only a parent (press-and-hold) can continue.
class BreakScreen extends ConsumerStatefulWidget {
  const BreakScreen({super.key, required this.onContinue});
  final void Function(BuildContext context, WidgetRef ref) onContinue;
  @override
  ConsumerState<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends ConsumerState<BreakScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(eventLogProvider).log('break');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppScreen(
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: HomeBtn()),
          const Spacer(),
          const Text('🌿', style: TextStyle(fontSize: 84)),
          const SizedBox(height: 12),
          Text(
            l.breakTitle,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l.breakMsg,
            style: const TextStyle(fontSize: 24, color: AppColors.muted),
          ),
          const Spacer(),
          HoldButton(
            label: l.parentContinue,
            duration: const Duration(seconds: 2),
            onComplete: () {
              ref.read(sessionProvider).resetSession();
              widget.onContinue(context, ref);
            },
          ),
        ],
      ),
    );
  }
}
