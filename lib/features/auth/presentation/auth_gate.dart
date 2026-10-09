import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/security/session.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/auth/presentation/setup_page.dart';
import 'package:cyber_vault/features/auth/presentation/unlock_page.dart';
import 'package:cyber_vault/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<VaultStatus>(
      sessionProvider.select((SessionState s) => s.status),
      (VaultStatus? previous, VaultStatus next) {
        if (previous == VaultStatus.unlocked && next != VaultStatus.unlocked) {
          // Close every pushed page (viewers, editors, dialogs) so no
          // decrypted content stays in the widget tree.
          rootNavigatorKey.currentState
              ?.popUntil((Route<dynamic> route) => route.isFirst);
        }
      },
    );

    final SessionState session = ref.watch(sessionProvider);
    return switch (session.status) {
      VaultStatus.loading => const _SplashView(),
      VaultStatus.error => _ErrorView(
          message: session.errorMessage ?? 'Unknown error.',
          onRetry: () => ref.read(sessionProvider.notifier).initialize(),
        ),
      VaultStatus.needsSetup => const SetupPage(),
      VaultStatus.locked => const UnlockPage(),
      VaultStatus.unlocked => const HomeShell(),
    };
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            VaultBadge(title: 'Cyber Vault'),
            SizedBox(height: 28),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
