import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

/// Pops `true` only when the user typed ERASE and confirmed.
class EraseVaultDialog extends StatefulWidget {
  const EraseVaultDialog({super.key});

  @override
  State<EraseVaultDialog> createState() => _EraseVaultDialogState();
}

class _EraseVaultDialogState extends State<EraseVaultDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrutalDialog(
      title: 'Erase everything?',
      danger: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'This permanently deletes all passwords, notes and documents on this device. It cannot be undone.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),
          VaultTextField(
            controller: _controller,
            label: 'Type ERASE to confirm',
            textCapitalization: TextCapitalization.characters,
            onChanged: (String value) => setState(() => _matches = value.trim() == 'ERASE'),
          ),
        ],
      ),
      actions: <Widget>[
        BrutalButton(
          label: 'Cancel',
          style: BrutalButtonStyle.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BrutalButton(
          label: 'Erase',
          style: BrutalButtonStyle.danger,
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
