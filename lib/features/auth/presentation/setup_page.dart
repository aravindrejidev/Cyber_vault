import 'package:cyber_vault/core/security/session.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  static const int _minLength = 10;

  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;
  bool _acknowledged = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final String password = _password.text;
    if (password.length < _minLength) {
      setState(() => _error = 'Use at least $_minLength characters.');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    if (!_acknowledged) {
      setState(() => _error = 'Please confirm that you understand the warning.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).createVault(password);
      // On success AuthGate replaces this page with the vault.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is VaultException
            ? e.message
            : 'Could not create the vault: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const VaultBadge(
                    title: 'Create your vault',
                    subtitle:
                        'Choose a strong master password. It is never stored anywhere.',
                  ),
                  const SizedBox(height: 28),
                  VaultTextField(
                    controller: _password,
                    label: 'Master password',
                    obscureText: _obscure,
                    prefixIcon: Icons.lock_outline,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PasswordStrengthMeter(password: _password.text),
                  const SizedBox(height: 16),
                  VaultTextField(
                    controller: _confirm,
                    label: 'Confirm master password',
                    obscureText: _obscure,
                    prefixIcon: Icons.lock_outline,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _acknowledged,
                    onChanged: _busy
                        ? null
                        : (bool? value) =>
                            setState(() => _acknowledged = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I understand that if I forget this password, my data cannot be recovered by anyone.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _create,
                      child: _busy
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Securing your vault...'),
                              ],
                            )
                          : const Text('Create vault'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
