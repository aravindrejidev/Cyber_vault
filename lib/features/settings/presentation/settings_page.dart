import 'package:cyber_vault/core/security/session.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/update/app_info.dart';
import 'package:cyber_vault/core/update/update_service.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/auth/presentation/erase_vault_dialog.dart';
import 'package:cyber_vault/features/settings/presentation/change_password_dialog.dart';
import 'package:cyber_vault/features/update/presentation/update_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final UpdateService _updates = UpdateService();
  bool _biometricBusy = false;
  bool _autoCheck = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadUpdatePrefs();
  }

  Future<void> _loadUpdatePrefs() async {
    final bool enabled = await _updates.isAutoCheckEnabled();
    if (!mounted) return;
    setState(() => _autoCheck = enabled);
  }

  Future<void> _toggleAutoCheck(bool value) async {
    setState(() => _autoCheck = value);
    await _updates.setAutoCheckEnabled(value);
  }

  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    await UpdateCoordinator.runManualCheck(context);
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _toggleBiometric(bool enable) async {
    setState(() => _biometricBusy = true);
    String? error;
    try {
      error = await ref.read(sessionProvider.notifier).setBiometricEnabled(enable);
    } catch (e) {
      error = 'Could not change biometric unlock: $e';
    }
    if (!mounted) return;
    setState(() => _biometricBusy = false);
    if (error != null) showSnack(context, error);
  }

  Future<void> _changePassword() async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => const ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      showSnack(context, 'Master password changed.');
    }
  }

  Future<void> _erase() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => const EraseVaultDialog(),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await ref.read(sessionProvider.notifier).eraseVault();
  }

  @override
  Widget build(BuildContext context) {
    final SessionState session = ref.watch(sessionProvider);
    final bool canToggle = session.biometricAvailable && !_biometricBusy;
    final bool updatesOn = _updates.isConfigured;

    return Scaffold(
      appBar: const BrutalAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 12, 28),
        children: <Widget>[
          const SectionLabel('Security'),
          BrutalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                BrutalSwitchTile(
                  icon: Icons.fingerprint,
                  title: 'Biometric unlock',
                  subtitle: session.biometricAvailable
                      ? 'Unlock with fingerprint or face'
                      : 'No biometrics enrolled on this device',
                  value: session.biometricEnabled,
                  onChanged: canToggle ? _toggleBiometric : null,
                ),
                const Divider(),
                _SettingTile(
                  icon: Icons.password,
                  title: 'Change master password',
                  onTap: _changePassword,
                ),
                const Divider(),
                _SettingTile(
                  icon: Icons.lock_outline,
                  title: 'Lock now',
                  onTap: () => ref.read(sessionProvider.notifier).lock(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Updates'),
          BrutalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _SettingTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  subtitle: updatesOn
                      ? 'v${AppInfo.version}'
                      : 'v${AppInfo.version} (updates are off in this build)',
                ),
                const Divider(),
                BrutalSwitchTile(
                  icon: Icons.system_update_alt,
                  title: 'Check on startup',
                  subtitle: 'Only asks GitHub whether a new release exists',
                  value: _autoCheck,
                  onChanged: updatesOn ? _toggleAutoCheck : null,
                ),
                const Divider(),
                _SettingTile(
                  icon: Icons.refresh,
                  title: 'Check for updates now',
                  trailing: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: (updatesOn && !_checking) ? _checkNow : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Protection'),
          const BrutalCard(
            child: Column(
              children: <Widget>[
                _InfoRow('Zero-knowledge: the master password is never stored.'),
                _InfoRow('Argon2id key derivation, AES-256-GCM encryption.'),
                _InfoRow('Passwords and notes live in a SQLCipher (AES-256) database.'),
                _InfoRow('Documents are encrypted on disk and opened from memory only.'),
                _InfoRow('Screenshots and app-switcher previews are blocked.'),
                _InfoRow('Auto-lock: 30 s in background, 3 min without touch.'),
                _InfoRow('Copied passwords are cleared from the clipboard after 30 s.'),
                _InfoRow(
                  'Your data never leaves the device. The network is used only to check and download app updates from GitHub.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Danger zone'),
          BrutalCard(
            padding: EdgeInsets.zero,
            borderColor: AppColors.danger,
            shadowColor: AppColors.danger,
            child: _SettingTile(
              icon: Icons.delete_forever_outlined,
              title: 'Erase vault',
              subtitle: 'Delete all data on this device',
              danger: true,
              onTap: _erase,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    Color tone = enabled ? AppColors.ink : AppColors.muted;
    if (danger) tone = AppColors.danger;
    final String? sub = subtitle;
    final Widget? end = trailing ?? (enabled ? Icon(Icons.chevron_right, color: tone) : null);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: tone, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(color: tone, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(sub, style: AppStyle.muted),
                    ),
                ],
              ),
            ),
            if (end != null) end,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(width: 8, height: 8, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppStyle.muted)),
        ],
      ),
    );
  }
}
