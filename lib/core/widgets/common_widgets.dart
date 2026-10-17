import 'package:cyber_vault/core/widgets/brutal_controls.dart';
import 'package:cyber_vault/core/widgets/brutal_inputs.dart';
import 'package:flutter/material.dart';

// One import for the whole design system.
export 'package:cyber_vault/core/widgets/brutal_controls.dart';
export 'package:cyber_vault/core/widgets/brutal_inputs.dart';
export 'package:cyber_vault/core/widgets/brutal_layout.dart';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool danger = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => BrutalDialog(
      title: title,
      danger: danger,
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: <Widget>[
        BrutalButton(
          label: 'Cancel',
          style: BrutalButtonStyle.outline,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        BrutalButton(
          label: confirmLabel,
          style: danger ? BrutalButtonStyle.danger : BrutalButtonStyle.primary,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for one line of text. Returns null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) =>
        _PromptDialog(title: title, label: label, initial: initial),
  );
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatDate(int millis) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrutalDialog(
      title: widget.title,
      content: VaultTextField(
        controller: _controller,
        label: widget.label,
        autofocus: true,
        onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: <Widget>[
        BrutalButton(
          label: 'Cancel',
          style: BrutalButtonStyle.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BrutalButton(
          label: 'Save',
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}
