import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/security/session.dart';
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
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BrandHeader(
                kicker: 'booting',
                title: 'Cyber\nVault',
                subtitle: 'Initializing secure storage...',
              ),
              SizedBox(height: 28),
              BrutalProgressBar(),
              SizedBox(height: 24),
            ],
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BrandHeader(
                kicker: 'error',
                title: 'Storage\nerror',
                subtitle: message,
                icon: Icons.error_outline,
              ),
              const SizedBox(height: 28),
              BrutalButton(label: 'Try again', onPressed: onRetry),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
