import 'package:cyber_vault/core/theme/app_theme.dart';
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Password generator',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neonCyan.withAlpha(120)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SelectableText(
                      _value,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        color: AppColors.neonGreen,
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
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text('Length: ${_length.round()}'),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lowercase (a-z)'),
              value: _lower,
              onChanged: (bool v) {
                _lower = v;
                _regenerate();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Uppercase (A-Z)'),
              value: _upper,
              onChanged: (bool v) {
                _upper = v;
                _regenerate();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Digits (0-9)'),
              value: _digits,
              onChanged: (bool v) {
                _digits = v;
                _regenerate();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Symbols (!@#...)'),
              value: _symbols,
              onChanged: (bool v) {
                _symbols = v;
                _regenerate();
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_value),
                child: const Text('Use this password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
