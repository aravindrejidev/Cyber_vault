import 'package:cyber_vault/core/crypto/crypto_service.dart';
import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/security/clipboard_guard.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/passwords/domain/password_entry.dart';
import 'package:cyber_vault/features/passwords/presentation/password_generator_sheet.dart';
import 'package:cyber_vault/features/passwords/presentation/password_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PasswordEditPage extends ConsumerStatefulWidget {
  const PasswordEditPage({super.key, this.entry});

  /// Null when creating a new entry.
  final PasswordEntry? entry;

  @override
  ConsumerState<PasswordEditPage> createState() => _PasswordEditPageState();
}

class _PasswordEditPageState extends ConsumerState<PasswordEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late bool _favorite;
  bool _obscure = true;
  bool _dirty = false;
  bool _saving = false;

  bool get _isNew => widget.entry == null;

  @override
  void initState() {
    super.initState();
    final PasswordEntry? e = widget.entry;
    _title = TextEditingController(text: e?.title ?? '');
    _username = TextEditingController(text: e?.username ?? '');
    _password = TextEditingController(text: e?.password ?? '');
    _url = TextEditingController(text: e?.url ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _favorite = e?.favorite ?? false;
    backgroundSignal.addListener(_onBackground);
  }

  @override
  void dispose() {
    backgroundSignal.removeListener(_onBackground);
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Re-mask the password as soon as the app leaves the foreground.
  void _onBackground() {
    if (mounted && !_obscure) {
      setState(() => _obscure = true);
    }
  }

  void _changed() => setState(() => _dirty = true);

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    try {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final PasswordEntry? existing = widget.entry;
      final PasswordEntry entry = PasswordEntry(
        id: existing?.id ?? CryptoService.newId(),
        title: _title.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        url: _url.text.trim(),
        notes: _notes.text,
        favorite: _favorite,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await ref.read(passwordRepositoryProvider).upsert(entry);
      ref.invalidate(passwordListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Could not save: $e');
    }
  }

  Future<void> _delete() async {
    final PasswordEntry? existing = widget.entry;
    if (existing == null) return;
    final bool confirmed = await confirmAction(
      context,
      title: 'Delete password?',
      message: 'Delete "${existing.title}" permanently?',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(passwordRepositoryProvider).delete(existing.id);
      ref.invalidate(passwordListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Could not delete: $e');
    }
  }

  Future<void> _copyPassword() async {
    if (_password.text.isEmpty) return;
    await ClipboardGuard.copySecret(_password.text);
    if (!mounted) return;
    showSnack(context, 'Password copied. Clipboard clears in 30 s.');
  }

  Future<void> _copyUsername() async {
    if (_username.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _username.text));
    if (!mounted) return;
    showSnack(context, 'Username copied.');
  }

  Future<void> _generate() async {
    final String? value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext ctx) => const PasswordGeneratorSheet(),
    );
    if (value == null || !mounted) return;
    setState(() {
      _password.text = value;
      _obscure = false;
      _dirty = true;
    });
  }

  Future<void> _confirmDiscard() async {
    final bool discard = await confirmAction(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes.',
      confirmLabel: 'Discard',
      danger: true,
    );
    if (discard && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New password' : 'Edit password'),
          actions: <Widget>[
            IconButton(
              tooltip: _favorite ? 'Remove from favorites' : 'Add to favorites',
              icon: Icon(
                _favorite ? Icons.star : Icons.star_border,
                color: _favorite ? AppColors.warning : null,
              ),
              onPressed: () => setState(() {
                _favorite = !_favorite;
                _dirty = true;
              }),
            ),
            if (!_isNew)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving ? null : _delete,
              ),
            IconButton(
              tooltip: 'Save',
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              VaultTextField(
                controller: _title,
                label: 'Title',
                hint: 'e.g. Gmail',
                prefixIcon: Icons.label_outline,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _changed(),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),
              VaultTextField(
                controller: _username,
                label: 'Username / email',
                prefixIcon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _changed(),
                suffix: IconButton(
                  tooltip: 'Copy username',
                  icon: const Icon(Icons.copy),
                  onPressed: _copyUsername,
                ),
              ),
              const SizedBox(height: 14),
              VaultTextField(
                controller: _password,
                label: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscure,
                monospace: true,
                onChanged: (_) => _changed(),
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: _obscure ? 'Show' : 'Hide',
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    IconButton(
                      tooltip: 'Copy password',
                      icon: const Icon(Icons.copy),
                      onPressed: _copyPassword,
                    ),
                    IconButton(
                      tooltip: 'Generate',
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.neonCyan,
                      ),
                      onPressed: _generate,
                    ),
                  ],
                ),
              ),
              if (_password.text.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                PasswordStrengthMeter(password: _password.text),
              ],
              const SizedBox(height: 14),
              VaultTextField(
                controller: _url,
                label: 'Website',
                hint: 'https://',
                prefixIcon: Icons.link,
                keyboardType: TextInputType.url,
                onChanged: (_) => _changed(),
              ),
              const SizedBox(height: 14),
              VaultTextField(
                controller: _notes,
                label: 'Notes',
                prefixIcon: Icons.notes,
                maxLines: null,
                minLines: 3,
                onChanged: (_) => _changed(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
