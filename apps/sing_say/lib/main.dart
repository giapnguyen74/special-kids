import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_core/core/progress/profile.dart';
import 'package:sk_core/core/ui/routes.dart';
import 'package:sk_core/core/ui/theme.dart';
import 'package:sk_core/l10n/app_localizations.dart';

import 'sing_say/sing_say_home.dart';

/// Standalone Sing & Say app: sing along, say sentences. Same parent area and shared core as the other apps.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const SingSayApp(),
    ),
  );
}

class SingSayApp extends ConsumerWidget {
  const SingSayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(profileProvider.select((p) => p.lang));
    return MaterialApp(
      title: 'Sing & Say',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(lang.name),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorObservers: [routeObserver],
      home: const SingSayHome(),
    );
  }
}
