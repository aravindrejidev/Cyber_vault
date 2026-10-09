import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/features/auth/presentation/auth_gate.dart';
import 'package:flutter/material.dart';

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyber Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      navigatorKey: rootNavigatorKey,
      builder: (BuildContext context, Widget? child) {
        return AutoLockScope(child: child ?? const SizedBox.shrink());
      },
      home: const AuthGate(),
    );
  }
}
