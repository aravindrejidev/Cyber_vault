import 'dart:io';

import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/update/apk_installer.dart';
import 'package:cyber_vault/core/update/app_info.dart';
import 'package:cyber_vault/core/update/update_info.dart';
import 'package:cyber_vault/core/update/update_service.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _screenColor = Color(0xFF03060B);
const TextStyle _buttonText = TextStyle(
  letterSpacing: 1.6,
  fontWeight: FontWeight.w700,
);

Future<void> showUpdateDialog(
  BuildContext context,
  UpdateInfo info,
  UpdateService service,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => UpdateDialog(info: info, service: service),
  );
}

enum _Phase { prompt, downloading, needsPermission, installing, error }

/// "Update available" popup. Flow: prompt -> download (with progress) ->
/// system installer. Android only installs the APK over the existing app when
/// both are signed with the same key, and the vault data is kept.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info, required this.service});

  final UpdateInfo info;
  final UpdateService service;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _Phase _phase = _Phase.prompt;
  int _received = 0;
  int _total = 0;
  String? _error;
  UpdateDownload? _download;
  File? _apk;

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _skip() async {
    await widget.service.skipVersion(widget.info.version);
    if (mounted) Navigator.of(context).pop();
  }

  void _later() => Navigator.of(context).pop();

  void _cancelDownload() {
    _download?.cancel();
    if (mounted) setState(() => _phase = _Phase.prompt);
  }

  void _retry() {
    _apk = null;
    _startDownload();
  }

  Future<void> _startDownload() async {
    final UpdateDownload download = UpdateDownload(widget.info);
    _download = download;
    setState(() {
      _phase = _Phase.downloading;
      _received = 0;
      _total = widget.info.apkSize;
      _error = null;
    });
    try {
      final File file = await download.run((int received, int total) {
        // A running download counts as activity (no inactivity lock).
        reportUserActivity();
        if (!mounted) return;
        setState(() {
          _received = received;
          _total = total;
        });
      });
      _apk = file;
      if (!mounted) return;
      await _install();
    } on UpdateCancelled {
      // The user cancelled; the dialog already went back to the first screen.
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Download failed: $e';
      });
    }
  }

  Future<void> _install() async {
    final File? file = _apk;
    if (file == null) {
      await _startDownload();
      return;
    }
    try {
      final bool allowed = await ApkInstaller.canInstall();
      if (!mounted) return;
      if (!allowed) {
        setState(() => _phase = _Phase.needsPermission);
        return;
      }
      // The installer leaves the app: do not auto-lock while it is open.
      LockGuard.suspendFor(const Duration(minutes: 2));
      await ApkInstaller.install(file.path);
      if (!mounted) return;
      setState(() => _phase = _Phase.installing);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Could not open the installer: ${e.message ?? e.code}';
      });
    }
  }

  Future<void> _openSettings() async {
    try {
      LockGuard.suspendFor(const Duration(minutes: 2));
      await ApkInstaller.openInstallSettings();
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Could not open the settings: ${e.message ?? e.code}';
      });
    }
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  List<Widget> _actions() {
    switch (_phase) {
      case _Phase.prompt:
        return _promptActions();
      case _Phase.downloading:
        return _downloadActions();
      case _Phase.needsPermission:
        return _permissionActions();
      case _Phase.installing:
        return _installingActions();
      case _Phase.error:
        return _errorActions();
    }
  }

  List<Widget> _promptActions() {
    return <Widget>[
      _BigButton(label: 'DOWNLOAD & INSTALL', onPressed: _startDownload),
      const SizedBox(height: 10),
      Row(
        children: <Widget>[
          Expanded(
            child: _SmallButton(label: "DON'T REMIND", onPressed: _skip),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SmallButton(label: 'LATER', onPressed: _later),
          ),
        ],
      ),
    ];
  }

  List<Widget> _downloadActions() {
    final double? fraction =
        _total > 0 ? (_received / _total).clamp(0.0, 1.0).toDouble() : null;
    final String percent =
        fraction == null ? '' : '${(fraction * 100).round()}%  -  ';
    final String sizes = _total > 0
        ? '${formatBytes(_received)} / ${formatBytes(_total)}'
        : formatBytes(_received);
    return <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: fraction, minHeight: 10),
      ),
      const SizedBox(height: 10),
      Text(
        'Downloading  $percent$sizes',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.neonGreen,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 14),
      _SmallButton(label: 'CANCEL', onPressed: _cancelDownload),
    ];
  }

  List<Widget> _permissionActions() {
    return <Widget>[
      const _Message(
        'Android needs your permission before this app can install updates. '
        'Allow it, come back here and tap INSTALL.',
      ),
      const SizedBox(height: 14),
      _BigButton(label: 'OPEN SETTINGS', onPressed: _openSettings),
      const SizedBox(height: 10),
      _SmallButton(label: 'INSTALL', onPressed: _install),
      const SizedBox(height: 10),
      _SmallButton(label: 'CLOSE', onPressed: _later),
    ];
  }

  List<Widget> _installingActions() {
    return <Widget>[
      const _Message(
        'The installer is open. Confirm the installation to finish updating. '
        'Your vault data is kept.',
      ),
      const SizedBox(height: 14),
      _SmallButton(label: 'INSTALL AGAIN', onPressed: _install),
      const SizedBox(height: 10),
      _SmallButton(label: 'CLOSE', onPressed: _later),
    ];
  }

  List<Widget> _errorActions() {
    return <Widget>[
      _Message(_error ?? 'Something went wrong.', color: AppColors.danger),
      const SizedBox(height: 14),
      _BigButton(label: 'RETRY', onPressed: _retry),
      const SizedBox(height: 10),
      _SmallButton(label: 'CLOSE', onPressed: _later),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.downloading,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _cancelDownload();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.neonCyan.withAlpha(150),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.neonCyan.withAlpha(50),
                  blurRadius: 30,
                ),
              ],
            ),
            child: SingleChildScrollView(
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _PanelHeader(),
                  const SizedBox(height: 16),
                  _VersionPanel(
                    current: AppInfo.version,
                    next: widget.info.version,
                  ),
                  const SizedBox(height: 18),
                  const _Label("WHAT'S NEW"),
                  const SizedBox(height: 8),
                  _NotesBox(text: widget.info.notes),
                  const SizedBox(height: 14),
                  _Label(
                    widget.info.apkSize > 0
                        ? 'DOWNLOAD SIZE   ${formatBytes(widget.info.apkSize)}'
                        : 'DOWNLOAD SIZE   UNKNOWN',
                  ),
                  const SizedBox(height: 16),
                  ..._actions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

class _PanelHeader extends StatelessWidget {
  const _PanelHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'UPDATE AVAILABLE',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
        ),
        // Glowing status LED.
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.neonGreen,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.neonGreen.withAlpha(170),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VersionPanel extends StatelessWidget {
  const _VersionPanel({required this.current, required this.next});

  final String current;
  final String next;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: _screenColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _VersionColumn(
              label: 'CURRENT',
              value: 'v$current',
              color: AppColors.neonGreen,
            ),
          ),
          const Icon(Icons.arrow_forward, color: AppColors.neonCyan, size: 30),
          Expanded(
            child: _VersionColumn(
              label: 'NEW',
              value: 'v$next',
              color: AppColors.neonCyan,
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionColumn extends StatelessWidget {
  const _VersionColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: color.withAlpha(190),
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              shadows: <Shadow>[
                Shadow(color: color.withAlpha(170), blurRadius: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesBox extends StatelessWidget {
  const _NotesBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _screenColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: SingleChildScrollView(
        primary: false,
        child: Text(
          text.isEmpty ? 'No release notes.' : text,
          style: const TextStyle(
            color: AppColors.neonGreen,
            fontFamily: 'monospace',
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.color = AppColors.textMuted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 13, height: 1.4),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label, style: _buttonText),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
