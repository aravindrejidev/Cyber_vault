import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.black,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
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

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

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
    return AlertDialog(
      title: Text(widget.title),
      content: VaultTextField(
        controller: _controller,
        label: widget.label,
        autofocus: true,
        onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Bordered surface with an optional neon glow.
class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glow ? AppColors.neonCyan.withAlpha(120) : AppColors.border,
        ),
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.neonCyan.withAlpha(40),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Glowing round emblem with a title, used on setup / unlock / splash screens.
class VaultBadge extends StatelessWidget {
  const VaultBadge({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.shield_outlined,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.neonCyan.withAlpha(150),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.neonCyan.withAlpha(70),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, size: 46, color: AppColors.neonCyan),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: AppColors.neonCyan.withAlpha(140)),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text field with the vault styling. Every keystroke counts as user activity
/// (so typing a long note does not trigger the inactivity lock) and the
/// keyboard is asked not to learn or suggest anything.
class VaultTextField extends StatelessWidget {
  const VaultTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.prefixIcon,
    this.autofocus = false,
    this.monospace = false,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final IconData? prefixIcon;
  final bool autofocus;
  final bool monospace;
  final bool enabled;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? null : minLines,
      keyboardType:
          keyboardType ?? (obscureText ? TextInputType.visiblePassword : null),
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      enabled: enabled,
      validator: validator,
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      style: monospace ? const TextStyle(fontFamily: 'monospace') : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: base,
        enabledBorder: base,
        focusedBorder: base.copyWith(
          borderSide: const BorderSide(color: AppColors.neonCyan, width: 1.4),
        ),
      ),
      onChanged: (String value) {
        reportUserActivity();
        onChanged?.call(value);
      },
      onFieldSubmitted: onSubmitted,
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
  });

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: (String value) {
          reportUserActivity();
          onChanged(value);
        },
        textInputAction: TextInputAction.search,
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppColors.surfaceHigh,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Password strength
// ---------------------------------------------------------------------------

class PasswordStrength {
  const PasswordStrength(this.score, this.label);

  /// 0 (very weak) .. 4 (strong)
  final int score;
  final String label;

  static PasswordStrength evaluate(String value) {
    if (value.isEmpty) return const PasswordStrength(0, 'Enter a password');

    final int length = value.length;
    final bool hasLower = RegExp(r'[a-z]').hasMatch(value);
    final bool hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final bool hasDigit = RegExp(r'\d').hasMatch(value);
    final bool hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
    final int classes =
        <bool>[hasLower, hasUpper, hasDigit, hasSymbol].where((bool b) => b).length;

    int score = 0;
    if (length >= 10) score++;
    if (length >= 14) score++;
    if (classes >= 3) score++;
    if (length >= 18 && classes >= 2) score++;
    if (length < 8) score = 0;

    const List<String> labels = <String>[
      'Very weak',
      'Weak',
      'Fair',
      'Good',
      'Strong',
    ];
    return PasswordStrength(score, labels[score]);
  }
}

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final PasswordStrength strength = PasswordStrength.evaluate(password);
    const List<Color> colors = <Color>[
      AppColors.danger,
      AppColors.danger,
      AppColors.warning,
      AppColors.neonGreen,
      AppColors.neonCyan,
    ];
    final Color color = colors[strength.score];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(
            4,
            (int i) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                decoration: BoxDecoration(
                  color: i < strength.score ? color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(strength.label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
