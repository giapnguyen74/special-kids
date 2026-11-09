import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
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
    this.sha256,
  });
  final String version;
  final int build;
  final String url;
  final String notes;

  /// Checked after download; a damaged or tampered file is never installed.
  final String? sha256;
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
        sha256: j['sha256'] as String?,
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

/// Fallback: download in the browser (the parent then opens the file).
Future<void> openUpdate(AppUpdate u) =>
    launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication);

// ---------------------------------------------------------------- in-app download + install

enum InstallPhase { idle, downloading, installing, needsPermission, failed }

class InstallState {
  const InstallState(this.phase, {this.percent = 0, this.error});
  final InstallPhase phase;
  final int percent;
  final String? error;
}

/// Downloads the update inside the app (with progress), checks its SHA-256, then opens Android's
/// "Update this app?" prompt — one tap for the parent. The child's data is kept (in-place update).
class UpdateInstaller extends Notifier<InstallState> {
  StreamSubscription<OtaEvent>? _sub;

  @override
  InstallState build() {
    ref.onDispose(() => _sub?.cancel());
    return const InstallState(InstallPhase.idle);
  }

  void start(AppUpdate u) {
    if (state.phase == InstallPhase.downloading ||
        state.phase == InstallPhase.installing) {
      return;
    }
    state = const InstallState(InstallPhase.downloading);
    _sub?.cancel();
    try {
      _sub = OtaUpdate()
          .execute(
            u.url,
            destinationFilename: 'update-${u.build}.apk',
            sha256checksum: u.sha256,
          )
          .listen(
            (e) {
              switch (e.status) {
                case OtaStatus.DOWNLOADING:
                  state = InstallState(
                    InstallPhase.downloading,
                    percent: int.tryParse(e.value ?? '') ?? state.percent,
                  );
                case OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE:
                  // The system prompt is up; if the parent cancels it, the button can be tapped again.
                  state = const InstallState(InstallPhase.installing);
                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                  state = const InstallState(InstallPhase.needsPermission);
                case OtaStatus.CANCELED:
                  state = const InstallState(InstallPhase.idle);
                case OtaStatus.ALREADY_RUNNING_ERROR:
                  break;
                default:
                  state = InstallState(
                    InstallPhase.failed,
                    error: '${e.status.name}: ${e.value ?? ''}',
                  );
              }
            },
            onError: (Object e) =>
                state = InstallState(InstallPhase.failed, error: '$e'),
          );
    } catch (e) {
      state = InstallState(InstallPhase.failed, error: '$e');
    }
  }

  void reset() => state = const InstallState(InstallPhase.idle);
}

final updateInstallerProvider = NotifierProvider<UpdateInstaller, InstallState>(
  UpdateInstaller.new,
);
