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
      error = await ref
          .read(sessionProvider.notifier)
          .setBiometricEnabled(enable);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          const _SectionLabel('Security'),
          NeonCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric unlock'),
                  subtitle: Text(
                    session.biometricAvailable
                        ? 'Unlock with fingerprint or face'
                        : 'No biometrics enrolled on this device',
                  ),
                  value: session.biometricEnabled,
                  onChanged: canToggle ? _toggleBiometric : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Change master password'),
                  onTap: _changePassword,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Lock now'),
                  onTap: () => ref.read(sessionProvider.notifier).lock(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Updates'),
          NeonCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: Text(
                    _updates.isConfigured
                        ? 'v${AppInfo.version}'
                        : 'v${AppInfo.version} (updates are off in this build)',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.system_update_alt),
                  title: const Text('Check on startup'),
                  subtitle: const Text(
                    'Only asks GitHub whether a new release exists',
                  ),
                  value: _autoCheck,
                  onChanged: _updates.isConfigured ? _toggleAutoCheck : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: _checking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  title: const Text('Check for updates now'),
                  enabled: _updates.isConfigured && !_checking,
                  onTap: _checkNow,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('How your data is protected'),
          const NeonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoRow(
                  icon: Icons.visibility_off_outlined,
                  text: 'Zero-knowledge: the master password is never stored.',
                ),
                _InfoRow(
                  icon: Icons.key_outlined,
                  text: 'Argon2id key derivation, AES-256-GCM encryption.',
                ),
                _InfoRow(
                  icon: Icons.storage_outlined,
                  text: 'Passwords and notes live in a SQLCipher (AES-256) database.',
                ),
                _InfoRow(
                  icon: Icons.folder_outlined,
                  text: 'Documents are encrypted on disk and opened from memory only.',
                ),
                _InfoRow(
                  icon: Icons.phone_android_outlined,
                  text: 'Screenshots and app-switcher previews are blocked.',
                ),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  text: 'Auto-lock: 30 s in background, 3 min without touch.',
                ),
                _InfoRow(
                  icon: Icons.content_paste,
                  text: 'Copied passwords are cleared from the clipboard after 30 s.',
                ),
                _InfoRow(
                  icon: Icons.wifi_off_outlined,
                  text: 'Your data never leaves the device. The network is used only to check and download app updates from GitHub.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Danger zone'),
          NeonCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: AppColors.danger,
              ),
              title: const Text(
                'Erase vault',
                style: TextStyle(color: AppColors.danger),
              ),
              subtitle: const Text('Delete all data on this device'),
              onTap: _erase,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.neonCyan,
          fontSize: 12,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.neonCyan),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
