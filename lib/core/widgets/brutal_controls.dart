import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum BrutalButtonStyle { primary, outline, danger }

/// Flat block button with a hard shadow that disappears when pressed.
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = BrutalButtonStyle.primary,
    this.expand = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BrutalButtonStyle style;
  final bool expand;
  final double height;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  static const double _offset = 4;
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;

    Color fill = AppColors.accent;
    Color fg = AppColors.black;
    Color border = AppColors.accent;
    Color shadow = AppColors.ink;
    if (!enabled) {
      fill = AppColors.panelHigh;
      fg = AppColors.muted;
      border = AppColors.line;
      shadow = AppColors.black;
    } else if (widget.style == BrutalButtonStyle.outline) {
      fill = AppColors.black;
      fg = AppColors.ink;
      border = AppColors.ink;
      shadow = AppColors.line;
    } else if (widget.style == BrutalButtonStyle.danger) {
      fill = AppColors.danger;
      fg = AppColors.black;
      border = AppColors.danger;
      shadow = AppColors.ink;
    }

    final bool pressed = enabled && _down;
    final IconData? icon = widget.icon;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (TapDownDetails details) => _set(true) : null,
        onTapUp: enabled ? (TapUpDetails details) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.only(right: _offset, bottom: _offset),
          child: Transform.translate(
            offset: pressed ? const Offset(_offset, _offset) : Offset.zero,
            child: Container(
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: border, width: AppStyle.stroke),
                boxShadow: pressed
                    ? const <BoxShadow>[]
                    : AppStyle.hardShadow(shadow, _offset),
              ),
              child: Row(
                mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      widget.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.button.copyWith(color: fg),
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

/// Square dialog: coloured title bar, heavy border, hard coloured shadow.
class BrutalDialog extends StatelessWidget {
  const BrutalDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.danger = false,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color tone = danger ? AppColors.danger : AppColors.accent;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          margin: const EdgeInsets.only(right: 8, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.black,
            border: Border.all(color: AppColors.ink, width: AppStyle.strokeHeavy),
            boxShadow: AppStyle.hardShadow(tone, 8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                color: tone,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppStyle.font,
                    color: AppColors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < actions.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: actions[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square on/off switch row. Same idea as SwitchListTile.
class BrutalSwitchTile extends StatelessWidget {
  const BrutalSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    final Color tone = enabled ? AppColors.ink : AppColors.muted;
    final String? sub = subtitle;
    final IconData? leading = icon;

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                reportUserActivity();
                onChanged!(!value);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                Icon(leading, color: tone, size: 22),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: tone,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(sub, style: AppStyle.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Toggle(on: value, enabled: enabled),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.enabled});

  final bool on;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.ink;
    if (!enabled) {
      border = AppColors.line;
    } else if (on) {
      border = AppColors.accent;
    }
    Color knob = AppColors.ink;
    if (!enabled) {
      knob = AppColors.line;
    } else if (on) {
      knob = AppColors.black;
    }
    return Container(
      width: 60,
      height: 30,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on && enabled ? AppColors.accent : AppColors.black,
        border: Border.all(color: border, width: AppStyle.stroke),
      ),
      child: Container(width: 20, height: 20, color: knob),
    );
  }
}

/// Square check box with a text, like CheckboxListTile.
class BrutalCheckTile extends StatelessWidget {
  const BrutalCheckTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    Color border = AppColors.ink;
    if (!enabled) {
      border = AppColors.line;
    } else if (value) {
      border = AppColors.accent;
    }
    return Semantics(
      checked: value,
      enabled: enabled,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                reportUserActivity();
                onChanged!(!value);
              }
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: value ? AppColors.accent : AppColors.black,
                border: Border.all(color: border, width: AppStyle.stroke),
              ),
              child: value
                  ? const Icon(Icons.check, size: 20, color: AppColors.black)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: enabled ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square progress bar. [value] null = unknown duration.
class BrutalProgressBar extends StatelessWidget {
  const BrutalProgressBar({super.key, this.value, this.height = 18});

  final double? value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double? fraction = value;
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.ink, width: AppStyle.stroke),
      ),
      child: fraction == null
          ? const LinearProgressIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.black,
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
                heightFactor: 1,
                child: Container(color: AppColors.accent),
              ),
            ),
    );
  }
}
