import 'package:cyber_vault/core/crypto/crypto_service.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/notes/domain/note_entry.dart';
import 'package:cyber_vault/features/notes/presentation/note_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pressing back (or the check button) saves the note automatically.
class NoteEditPage extends ConsumerStatefulWidget {
  const NoteEditPage({super.key, this.note});

  /// Null when creating a new note.
  final NoteEntry? note;

  @override
  ConsumerState<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends ConsumerState<NoteEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _dirty = false;
  bool _saving = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _saveAndClose() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final String title = _title.text.trim();
      final String body = _body.text;
      final NoteEntry? existing = widget.note;
      final bool empty = title.isEmpty && body.trim().isEmpty;

      // A brand-new empty note is simply discarded.
      if (!(existing == null && empty)) {
        final int now = DateTime.now().millisecondsSinceEpoch;
        final NoteEntry note = NoteEntry(
          id: existing?.id ?? CryptoService.newId(),
          title: title.isEmpty ? 'Untitled note' : title,
          body: body,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        await ref.read(noteRepositoryProvider).upsert(note);
        ref.invalidate(noteListProvider);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Could not save: $e');
    }
  }

  Future<void> _delete() async {
    final NoteEntry? existing = widget.note;
    if (existing == null) return;
    final bool confirmed = await confirmAction(
      context,
      title: 'Delete note?',
      message: 'Delete "${existing.title}" permanently?',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(noteRepositoryProvider).delete(existing.id);
      ref.invalidate(noteListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Could not delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _saveAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New note' : 'Edit note'),
          actions: <Widget>[
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
              onPressed: _saving ? null : _saveAndClose,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            VaultTextField(
              controller: _title,
              label: 'Title',
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _changed(),
            ),
            const SizedBox(height: 14),
            VaultTextField(
              controller: _body,
              label: 'Note',
              maxLines: null,
              minLines: 14,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _changed(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
