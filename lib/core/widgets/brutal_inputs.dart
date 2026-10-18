import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Square text field with the label on the border. Every keystroke counts as
/// user activity (so typing a long note does not trigger the inactivity lock)
/// and the keyboard is asked not to learn or suggest anything.
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
    const OutlineInputBorder base = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.ink, width: AppStyle.stroke),
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
      cursorColor: AppColors.accent,
      style: TextStyle(
        fontFamily: AppStyle.font,
        fontSize: 15,
        color: enabled ? AppColors.ink : AppColors.muted,
      ),
      decoration: InputDecoration(
        labelText: label.toUpperCase(),
        labelStyle: const TextStyle(
          fontFamily: AppStyle.font,
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: AppStyle.font,
          color: AppColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: AppColors.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.black,
        contentPadding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
        border: base,
        enabledBorder: base,
        disabledBorder: base.copyWith(
          borderSide: const BorderSide(color: AppColors.line, width: AppStyle.stroke),
        ),
        focusedBorder: base.copyWith(
          borderSide: const BorderSide(color: AppColors.accent, width: AppStyle.strokeHeavy),
        ),
        errorBorder: base.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: AppStyle.stroke),
        ),
        focusedErrorBorder: base.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: AppStyle.strokeHeavy),
        ),
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontWeight: FontWeight.w700,
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
    const OutlineInputBorder base = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.ink, width: AppStyle.stroke),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: TextField(
        onChanged: (String value) {
          reportUserActivity();
          onChanged(value);
        },
        textInputAction: TextInputAction.search,
        enableSuggestions: false,
        autocorrect: false,
        enableIMEPersonalizedLearning: false,
        cursorColor: AppColors.accent,
        style: const TextStyle(fontFamily: AppStyle.font, fontSize: 15),
        decoration: InputDecoration(
          hintText: '${hint.toUpperCase()}...',
          hintStyle: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.accent),
          filled: true,
          fillColor: AppColors.black,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          border: base,
          enabledBorder: base,
          focusedBorder: base.copyWith(
            borderSide: const BorderSide(color: AppColors.accent, width: AppStyle.strokeHeavy),
          ),
        ),
      ),
    );
  }
}

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
    final int classes = <bool>[hasLower, hasUpper, hasDigit, hasSymbol]
        .where((bool b) => b)
        .length;

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
      AppColors.warn,
      AppColors.accent,
      AppColors.accent,
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
                height: 12,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                decoration: BoxDecoration(
                  color: i < strength.score ? color : AppColors.black,
                  border: Border.all(
                    color: i < strength.score ? color : AppColors.line,
                    width: AppStyle.stroke,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strength.label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}
