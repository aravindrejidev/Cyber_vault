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
      BrutalButton(
        label: 'Download & install',
        icon: Icons.download,
        onPressed: _startDownload,
      ),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          Expanded(
            child: BrutalButton(
              label: "Don't remind",
              style: BrutalButtonStyle.outline,
              height: 46,
              onPressed: _skip,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BrutalButton(
              label: 'Later',
              style: BrutalButtonStyle.outline,
              height: 46,
              onPressed: _later,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _downloadActions() {
    final double? fraction =
        _total > 0 ? (_received / _total).clamp(0.0, 1.0).toDouble() : null;
    final String percent = fraction == null ? '' : '${(fraction * 100).round()}%  -  ';
    final String sizes = _total > 0
        ? '${formatBytes(_received)} / ${formatBytes(_total)}'
        : formatBytes(_received);
    return <Widget>[
      BrutalProgressBar(value: fraction, height: 22),
      const SizedBox(height: 10),
      Text(
        'DOWNLOADING  $percent$sizes',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 14),
      BrutalButton(
        label: 'Cancel',
        style: BrutalButtonStyle.outline,
        height: 46,
        onPressed: _cancelDownload,
      ),
    ];
  }

  List<Widget> _permissionActions() {
    return <Widget>[
      const _Message(
        'Android needs your permission before this app can install updates. '
        'Allow it, come back here and tap INSTALL.',
      ),
      const SizedBox(height: 14),
      BrutalButton(label: 'Open settings', icon: Icons.settings, onPressed: _openSettings),
      const SizedBox(height: 6),
      BrutalButton(
        label: 'Install',
        style: BrutalButtonStyle.outline,
        height: 46,
        onPressed: _install,
      ),
      const SizedBox(height: 6),
      BrutalButton(
        label: 'Close',
        style: BrutalButtonStyle.outline,
        height: 46,
        onPressed: _later,
      ),
    ];
  }

  List<Widget> _installingActions() {
    return <Widget>[
      const _Message(
        'The installer is open. Confirm the installation to finish updating. '
        'Your vault data is kept.',
      ),
      const SizedBox(height: 14),
      BrutalButton(label: 'Install again', onPressed: _install),
      const SizedBox(height: 6),
      BrutalButton(
        label: 'Close',
        style: BrutalButtonStyle.outline,
        height: 46,
        onPressed: _later,
      ),
    ];
  }

  List<Widget> _errorActions() {
    return <Widget>[
      ErrorBox(_error ?? 'Something went wrong.'),
      const SizedBox(height: 16),
      BrutalButton(label: 'Retry', icon: Icons.refresh, onPressed: _retry),
      const SizedBox(height: 6),
      BrutalButton(
        label: 'Close',
        style: BrutalButtonStyle.outline,
        height: 46,
        onPressed: _later,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String sizeText = widget.info.apkSize > 0
        ? 'DOWNLOAD SIZE   ${formatBytes(widget.info.apkSize)}'
        : 'DOWNLOAD SIZE   UNKNOWN';
    return PopScope(
      canPop: _phase != _Phase.downloading,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _cancelDownload();
      },
      child: BrutalDialog(
        title: 'Update available',
        actions: const <Widget>[],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _VersionPanel(current: AppInfo.version, next: widget.info.version),
            const SizedBox(height: 20),
            const _Label("WHAT'S NEW"),
            const SizedBox(height: 8),
            _NotesBox(text: widget.info.notes),
            const SizedBox(height: 14),
            _Label(sizeText),
            const SizedBox(height: 18),
            ..._actions(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

class _VersionPanel extends StatelessWidget {
  const _VersionPanel({required this.current, required this.next});

  final String current;
  final String next;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.ink, width: AppStyle.stroke),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _VersionColumn(
              label: 'CURRENT',
              value: 'v$current',
              color: AppColors.muted,
            ),
          ),
          const Icon(Icons.arrow_forward, color: AppColors.accent, size: 32),
          Expanded(
            child: _VersionColumn(
              label: 'NEW',
              value: 'v$next',
              color: AppColors.accent,
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
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900),
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
        color: AppColors.panel,
        border: Border.all(color: AppColors.line, width: AppStyle.stroke),
      ),
      child: SingleChildScrollView(
        primary: false,
        child: _NotesText(text),
      ),
    );
  }
}

/// Release notes as written by the release workflow: short heading lines
/// ("New", "Fixes") and bullet lines starting with a dot.
class _NotesText extends StatelessWidget {
  const _NotesText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const Text('No release notes.', style: AppStyle.muted);
    }
    final List<Widget> lines = <Widget>[];
    for (final String raw in text.split('\n')) {
      final String line = raw.trimRight();
      if (line.isEmpty) {
        lines.add(const SizedBox(height: 10));
      } else if (line.startsWith('•')) {
        lines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: ColoredBox(color: AppColors.accent),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    line.substring(1).trim(),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.length <= 24) {
        lines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line.toUpperCase(), style: AppStyle.label),
          ),
        );
      } else {
        lines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        );
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);
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
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: TextAlign.center, style: AppStyle.muted);
  }
}
