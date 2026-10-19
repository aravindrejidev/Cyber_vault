import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/passwords/domain/password_generator.dart';
import 'package:flutter/material.dart';

/// Pops the chosen password (String) or null when dismissed.
class PasswordGeneratorSheet extends StatefulWidget {
  const PasswordGeneratorSheet({super.key});

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  double _length = 20;
  bool _lower = true;
  bool _upper = true;
  bool _digits = true;
  bool _symbols = true;
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = _make();
  }

  String _make() {
    return PasswordGenerator.generate(
      length: _length.round(),
      lower: _lower,
      upper: _upper,
      digits: _digits,
      symbols: _symbols,
    );
  }

  void _regenerate() => setState(() => _value = _make());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SectionLabel('Generator'),
            BrutalCard(
              shadowColor: AppColors.accent,
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SelectableText(
                      _value,
                      style: const TextStyle(
                        fontFamily: AppStyle.font,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Regenerate',
                    icon: const Icon(Icons.refresh),
                    onPressed: _regenerate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Text(
                  'LENGTH ${_length.round()}',
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
                Expanded(
                  child: Slider(
                    value: _length,
                    min: 8,
                    max: 48,
                    divisions: 40,
                    label: '${_length.round()}',
                    onChanged: (double v) {
                      _length = v;
                      _regenerate();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            BrutalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  BrutalSwitchTile(
                    title: 'Lowercase (a-z)',
                    value: _lower,
                    onChanged: (bool v) {
                      _lower = v;
                      _regenerate();
                    },
                  ),
                  const Divider(),
                  BrutalSwitchTile(
                    title: 'Uppercase (A-Z)',
                    value: _upper,
                    onChanged: (bool v) {
                      _upper = v;
                      _regenerate();
                    },
                  ),
                  const Divider(),
                  BrutalSwitchTile(
                    title: 'Digits (0-9)',
                    value: _digits,
                    onChanged: (bool v) {
                      _digits = v;
                      _regenerate();
                    },
                  ),
                  const Divider(),
                  BrutalSwitchTile(
                    title: 'Symbols (!@#...)',
                    value: _symbols,
                    onChanged: (bool v) {
                      _symbols = v;
                      _regenerate();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            BrutalButton(
              label: 'Use this password',
              icon: Icons.check,
              onPressed: () => Navigator.of(context).pop(_value),
            ),
          ],
        ),
      ),
    );
  }
}
