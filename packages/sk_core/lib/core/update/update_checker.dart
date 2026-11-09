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

/// Result of an update check (shown in Settings; [update] drives the banner).
class UpdateStatus {
  UpdateStatus({
    required this.current,
    this.update,
    this.error,
    this.checked = true,
  });
  final String current; // installed version, e.g. "1.0.1 (10001)"
  final AppUpdate? update;
  final String? error;

  /// false = checks are off (web, iOS, dev build without a feed URL).
  final bool checked;
}

/// Compares the installed build with the published feed (Android only; iOS updates via TestFlight / App Store).
/// Android itself guarantees the download is genuine: an update installs only if it is signed with the same key.
/// autoDispose: checked again every time the parent area is opened (not only once per app start).
final updateStatusProvider = FutureProvider.autoDispose<UpdateStatus>((
  ref,
) async {
  var current = '?';
  try {
    final info = await PackageInfo.fromPlatform();
    current = '${info.version} (${info.buildNumber})';
    if (kIsWeb ||
        updateFeedUrl.isEmpty ||
        defaultTargetPlatform != TargetPlatform.android) {
      return UpdateStatus(current: current, checked: false);
    }
    final res = await http
        .get(Uri.parse(updateFeedUrl), headers: {'Cache-Control': 'no-cache'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      return UpdateStatus(current: current, error: 'HTTP ${res.statusCode}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final build = j['build'] as int;
    if (build <= (int.tryParse(info.buildNumber) ?? 0)) {
      return UpdateStatus(current: current);
    }
    return UpdateStatus(
      current: current,
      update: AppUpdate(
        version: j['version'] as String,
        build: build,
        url: j['apk'] as String,
        notes: j['notes'] as String? ?? '',
      ),
    );
  } catch (e) {
    return UpdateStatus(
      current: current,
      error: e.toString().split('\n').first,
    );
  }
});

/// The available update, if any (for the banner).
final appUpdateProvider = Provider.autoDispose<AppUpdate?>(
  (ref) => ref.watch(updateStatusProvider).value?.update,
);

Future<void> openUpdate(AppUpdate u) =>
    launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication);
