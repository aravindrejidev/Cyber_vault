import 'package:cyber_vault/core/security/session.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/auth/presentation/erase_vault_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Offer biometrics right away when enabled.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _biometricUnlock(automatic: true),
    );
  }

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _biometricUnlock({bool automatic = false}) async {
    if (!mounted || _busy) return;
    if (!ref.read(sessionProvider).biometricEnabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bool ok = await ref.read(sessionProvider.notifier).unlockWithBiometrics();
      if (!ok && mounted) {
        setState(() {
          _busy = false;
          if (!automatic) _error = 'Biometric unlock was cancelled or failed.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is VaultException ? e.message : 'Biometric unlock failed: $e';
      });
    }
  }

  Future<void> _unlock() async {
    final String password = _controller.text;
    if (password.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bool ok = await ref.read(sessionProvider.notifier).unlockWithPassword(password);
      if (!ok && mounted) {
        setState(() {
          _busy = false;
          _error = 'Wrong master password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is VaultException ? e.message : 'Unlock failed: $e';
      });
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
    final bool canUseBiometrics = session.biometricEnabled && session.biometricAvailable;

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
                  const BrandHeader(
                    kicker: 'locked',
                    title: 'Enter\nmaster key',
                    subtitle: 'Your vault is encrypted. Unlock it to continue.',
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 32),
                  VaultTextField(
                    controller: _controller,
                    label: 'Master password',
                    obscureText: _obscure,
                    prefixIcon: Icons.lock_outline,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _unlock(),
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    ErrorBox(_error!),
                  ],
                  const SizedBox(height: 24),
                  BrutalButton(
                    label: _busy ? 'Working...' : 'Unlock',
                    icon: _busy ? null : Icons.lock_open,
                    onPressed: _busy ? null : _unlock,
                  ),
                  if (_busy) ...<Widget>[
                    const SizedBox(height: 12),
                    const BrutalProgressBar(),
                  ],
                  if (canUseBiometrics) ...<Widget>[
                    const SizedBox(height: 14),
                    BrutalButton(
                      label: 'Use biometrics',
                      icon: Icons.fingerprint,
                      style: BrutalButtonStyle.outline,
                      onPressed: _busy ? null : () => _biometricUnlock(),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : _erase,
                      child: const Text(
                        'FORGOT PASSWORD? ERASE VAULT',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
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
