import 'package:cyber_vault/core/security/session.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pops `true` when the master password was changed.
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  static const int _minLength = 10;

  final TextEditingController _oldPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_oldPassword.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (_newPassword.text.length < _minLength) {
      setState(() => _error = 'Use at least $_minLength characters.');
      return;
    }
    if (_newPassword.text != _confirm.text) {
      setState(() => _error = 'The new passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bool ok = await ref
          .read(sessionProvider.notifier)
          .changeMasterPassword(_oldPassword.text, _newPassword.text);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _busy = false;
          _error = 'The current password is wrong.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is VaultException
            ? e.message
            : 'Could not change the password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Change master password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              VaultTextField(
                controller: _oldPassword,
                label: 'Current password',
                obscureText: true,
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
              VaultTextField(
                controller: _newPassword,
                label: 'New password',
                obscureText: true,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              PasswordStrengthMeter(password: _newPassword.text),
              const SizedBox(height: 12),
              VaultTextField(
                controller: _confirm,
                label: 'Confirm new password',
                obscureText: true,
                enabled: !_busy,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Change'),
          ),
        ],
      ),
    );
  }
}
