import 'package:cyber_vault/core/update/app_info.dart';
import 'package:cyber_vault/core/update/update_info.dart';
import 'package:cyber_vault/core/update/update_service.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/update/presentation/update_dialog.dart';
import 'package:flutter/material.dart';

class UpdateCoordinator {
  UpdateCoordinator._();

  static bool _startupCheckDone = false;

  /// Runs once per app start, after the vault is unlocked. Silent unless a
  /// newer version exists that the user has not chosen "Don't remind" for.
  static Future<void> runStartupCheck(BuildContext context) async {
    if (_startupCheckDone) return;
    _startupCheckDone = true;

    final UpdateService service = UpdateService();
    if (!service.isConfigured) return;
    await service.cleanupDownloads();
    if (!await service.isAutoCheckEnabled()) return;

    UpdateInfo? info;
    try {
      info = await service.checkForUpdate();
    } catch (_) {
      return; // No internet, GitHub busy, ...: stay quiet on startup.
    }
    if (info == null) return;
    if (await service.skippedVersion() == info.version) return;
    if (!context.mounted) return;
    await showUpdateDialog(context, info, service);
  }

  /// "Check for updates now" in Settings: always reports what happened.
  static Future<void> runManualCheck(BuildContext context) async {
    final UpdateService service = UpdateService();
    if (!service.isConfigured) {
      showSnack(context, 'Updates are not available in this build.');
      return;
    }
    showSnack(context, 'Checking for updates...');

    UpdateInfo? info;
    try {
      info = await service.checkForUpdate();
    } on UpdateException catch (e) {
      if (context.mounted) showSnack(context, e.message);
      return;
    } catch (e) {
      if (context.mounted) showSnack(context, 'Update check failed: $e');
      return;
    }
    if (!context.mounted) return;

    if (info == null) {
      showSnack(context, 'You are on the latest version (v${AppInfo.version}).');
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await showUpdateDialog(context, info, service);
  }
}
