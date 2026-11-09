import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Update feed URL, baked in at build time by the Makefile:
///   `https://github.com/giapnguyen74/app-releases/releases/download/APP-feed/latest.json`
/// Empty in dev builds -> no update checks.
const updateFeedUrl = String.fromEnvironment('SK_FEED_URL');

class AppUpdate {
  AppUpdate({
    required this.version,
    required this.build,
    required this.url,
    required this.notes,
  });
  final String version;
  final int build;
  final String url;
  final String notes;
}

/// Compares the installed build with the published feed (Android only; iOS updates via TestFlight / App Store).
/// Android itself guarantees the download is genuine: an update installs only if it is signed with the same key.
final appUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  if (kIsWeb ||
      updateFeedUrl.isEmpty ||
      defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  try {
    final info = await PackageInfo.fromPlatform();
    final res = await http
        .get(Uri.parse(updateFeedUrl))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final build = j['build'] as int;
    if (build <= (int.tryParse(info.buildNumber) ?? 0)) return null;
    return AppUpdate(
      version: j['version'] as String,
      build: build,
      url: j['apk'] as String,
      notes: j['notes'] as String? ?? '',
    );
  } catch (_) {
    return null; // offline or feed missing: just no banner
  }
});

Future<void> openUpdate(AppUpdate u) =>
    launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication);
