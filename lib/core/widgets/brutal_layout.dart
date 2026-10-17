import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Square app bar with a heavy white bottom line and a "> TITLE" heading.
class BrutalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrutalAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 58,
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: const Border(
        bottom: BorderSide(color: AppColors.ink, width: AppStyle.strokeHeavy),
      ),
      title: Text(
        '> ${title.toUpperCase()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppStyle.font,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          color: AppColors.ink,
        ),
      ),
      actions: <Widget>[...?actions, const SizedBox(width: 4)],
    );
  }
}

/// Black box with a 2 px white border and a hard offset shadow. With [onTap]
/// it "presses in" like a physical button.
class BrutalCard extends StatefulWidget {
  const BrutalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.shadowColor = AppColors.line,
    this.borderColor = AppColors.ink,
    this.fill = AppColors.black,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color shadowColor;
  final Color borderColor;
  final Color fill;

  @override
  State<BrutalCard> createState() => _BrutalCardState();
}

class _BrutalCardState extends State<BrutalCard> {
  static const double _offset = 4;
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool tappable = widget.onTap != null;
    final bool pressed = tappable && _down;

    final Widget box = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.fill,
        border: Border.all(color: widget.borderColor, width: AppStyle.stroke),
        boxShadow: pressed
            ? const <BoxShadow>[]
            : AppStyle.hardShadow(widget.shadowColor, _offset),
      ),
      child: widget.child,
    );

    final Widget framed = Padding(
      padding: const EdgeInsets.only(right: _offset, bottom: _offset),
      child: Transform.translate(
        offset: pressed ? const Offset(_offset, _offset) : Offset.zero,
        child: box,
      ),
    );

    if (!tappable) return framed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails details) => _set(true),
      onTapUp: (TapUpDetails details) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: framed,
    );
  }
}

/// One row of a list: [leading] box, title, subtitle, [trailing] actions.
class BrutalTile extends StatelessWidget {
  const BrutalTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleSuffix,
    this.onTap,
    this.shadowColor = AppColors.line,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? titleSuffix;
  final VoidCallback? onTap;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    final String? sub = subtitle;
    return BrutalCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      onTap: onTap,
      shadowColor: shadowColor,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (titleSuffix != null) ...<Widget>[
                      const SizedBox(width: 8),
                      titleSuffix!,
                    ],
                  ],
                ),
                if (sub != null && sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyle.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Square box holding an icon or a letter.
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    this.icon,
    this.text,
    this.color = AppColors.accent,
    this.size = 44,
  });

  final IconData? icon;
  final String? text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? letter = text;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: color, width: AppStyle.stroke),
      ),
      child: letter != null
          ? Text(
              letter,
              style: TextStyle(
                color: color,
                fontSize: size * 0.45,
                fontWeight: FontWeight.w900,
              ),
            )
          : Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// "// SECTION" label in the accent colour.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('// ${text.toUpperCase()}', style: AppStyle.label),
    );
  }
}

/// Small boxed number, e.g. the number of entries in a list.
class CountTag extends StatelessWidget {
  const CountTag(this.count, {super.key});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final int? value = count;
    if (value == null) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent, width: AppStyle.stroke),
        ),
        child: Text(
          '$value',
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Solid little label, e.g. "NEW".
class StatusTag extends StatelessWidget {
  const StatusTag(this.text, {super.key, this.color = AppColors.accent});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFF3B30),
        border: Border.all(color: AppColors.danger, width: AppStyle.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconBox(icon: icon, size: 72),
            const SizedBox(height: 22),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: AppStyle.muted),
          ],
        ),
      ),
    );
  }
}

/// Big left-aligned heading block for the setup / unlock / splash screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.subtitle,
    this.icon = Icons.shield_outlined,
  });

  final String kicker;
  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final String? sub = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        IconBox(icon: icon, size: 60),
        const SizedBox(height: 24),
        Text('// ${kicker.toUpperCase()}', style: AppStyle.label),
        const SizedBox(height: 10),
        Text(title.toUpperCase(), style: AppStyle.heading),
        if (sub != null) ...<Widget>[
          const SizedBox(height: 14),
          Text(sub, style: AppStyle.muted),
        ],
      ],
    );
  }
}
