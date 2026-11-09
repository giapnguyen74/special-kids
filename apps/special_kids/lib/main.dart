import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/skills/skills.dart';
import 'package:snack_beats_game/snack_beats/snack_beats.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';

import 'hub/hub_screen.dart';

import 'package:sk_core/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        // Games in this app (for the parent's lesson settings).
        gameSkillSpecsProvider.overrideWithValue(const [SnackBeats.skillSpec]),
      ],
      child: const SpecialKidsApp(),
    ),
  );
}

class SpecialKidsApp extends ConsumerWidget {
  const SpecialKidsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(profileProvider.select((p) => p.lang));
    return MaterialApp(
      title: 'Special Kids',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(lang.name),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorObservers: [routeObserver],
      home: const HubScreen(),
    );
  }
}
