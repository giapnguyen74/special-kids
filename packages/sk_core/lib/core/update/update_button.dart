import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/lang.dart';
import '../progress/profile.dart';
import '../ui/palette.dart';
import '../ui/theme.dart';
import 'update_checker.dart';

/// "Update" button with in-app download progress; falls back to the browser on errors.
class UpdateButton extends ConsumerWidget {
  const UpdateButton({super.key, required this.update});
  final AppUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vi = ref.watch(profileProvider.select((p) => p.lang)) == Lang.vi;
    String t(String en, String v) => vi ? v : en;
    final st = ref.watch(updateInstallerProvider);
    final installer = ref.read(updateInstallerProvider.notifier);

    switch (st.phase) {
      case InstallPhase.downloading:
        return SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${t('Downloading', 'Đang tải')} ${st.percent}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: st.percent > 0 ? st.percent / 100 : null,
                  minHeight: 10,
                  color: Pure.green,
                  backgroundColor: Pure.green.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        );
      case InstallPhase.installing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              t('Tap "Update" on the screen', 'Bấm "Cập nhật" trên màn hình'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => installer.start(update),
              child: Text(t('Show again', 'Hiện lại')),
            ),
          ],
        );
      case InstallPhase.needsPermission || InstallPhase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 170,
              child: Text(
                st.phase == InstallPhase.needsPermission
                    ? t(
                        'Allow "Install unknown apps" for this app, then try again.',
                        'Hãy cho phép "Cài ứng dụng không rõ nguồn" cho app này rồi thử lại.',
                      )
                    : t(
                        'Could not update in the app.',
                        'Không cập nhật được trong app.',
                      ),
                textAlign: TextAlign.end,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () => installer.start(update),
                  child: Text(t('Try again', 'Thử lại')),
                ),
                TextButton(
                  onPressed: () => openUpdate(update),
                  child: Text(t('Browser', 'Tải bằng trình duyệt')),
                ),
              ],
            ),
          ],
        );
      case InstallPhase.idle:
        return FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Pure.green),
          onPressed: () => installer.start(update),
          child: Text(t('Update', 'Cập nhật')),
        );
    }
  }
}
