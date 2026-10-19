import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/security/clipboard_guard.dart';
import 'package:cyber_vault/core/security/temp_cleaner.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/documents/data/document_repository.dart';
import 'package:cyber_vault/features/documents/domain/document_entry.dart';
import 'package:cyber_vault/features/documents/presentation/document_providers.dart';
import 'package:cyber_vault/features/documents/presentation/document_viewer_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Add document" (entry == null) and the detail / edit page of an existing
/// document. A document has a name, one or more photos / PDFs (no limit on the
/// number of files) and optional User ID, URL, password and note.
class DocumentEditPage extends ConsumerStatefulWidget {
  const DocumentEditPage({super.key, this.entry});

  final DocumentEntry? entry;

  @override
  ConsumerState<DocumentEditPage> createState() => _DocumentEditPageState();
}

class _DocumentEditPageState extends ConsumerState<DocumentEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _userId;
  late final TextEditingController _url;
  late final TextEditingController _password;
  late final TextEditingController _notes;

  /// Files picked in this session, not stored yet.
  final List<PendingFile> _pending = <PendingFile>[];

  /// Ids of stored files the user removed (deleted when saving).
  final Set<String> _removed = <String>{};

  bool _obscure = true;
  bool _dirty = false;
  bool _saving = false;
  String _progress = '';

  bool get _isNew => widget.entry == null;

  List<DocumentFile> get _keptFiles {
    final List<DocumentFile> all = widget.entry?.files ?? const <DocumentFile>[];
    return all.where((DocumentFile f) => !_removed.contains(f.id)).toList();
  }

  @override
  void initState() {
    super.initState();
    final DocumentEntry? e = widget.entry;
    _name = TextEditingController(text: e?.name ?? '');
    _userId = TextEditingController(text: e?.userId ?? '');
    _url = TextEditingController(text: e?.url ?? '');
    _password = TextEditingController(text: e?.password ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    backgroundSignal.addListener(_onBackground);
  }

  @override
  void dispose() {
    backgroundSignal.removeListener(_onBackground);
    _name.dispose();
    _userId.dispose();
    _url.dispose();
    _password.dispose();
    _notes.dispose();
    // Picked files were copied to the app cache by the file picker.
    TempCleaner.clear();
    super.dispose();
  }

  /// Re-mask the password as soon as the app leaves the foreground.
  void _onBackground() {
    if (mounted && !_obscure) {
      setState(() => _obscure = true);
    }
  }

  void _changed() => setState(() => _dirty = true);

  Future<void> _pickFiles() async {
    FilePickerResult? result;
    try {
      // The picker leaves the app; do not auto-lock while it is open.
      // Files are NOT read into memory here: only their names and cache paths.
      result = await LockGuard.suspendWhile<FilePickerResult?>(
        () => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: DocumentKind.supportedExtensions,
          allowMultiple: true,
          withData: false,
          compressionQuality: 0,
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the file picker: $e');
      return;
    }
    if (result == null || result.files.isEmpty || !mounted) return;

    final List<PlatformFile> picked = result.files;
    int skipped = 0;
    setState(() {
      for (final PlatformFile file in picked) {
        final String? path = file.path;
        final bool supported = DocumentKind.fromFileName(file.name) != null;
        final bool tooBig = file.size > DocumentRepository.maxFileBytes;
        final bool duplicate =
            path != null && _pending.any((PendingFile p) => p.path == path);
        if (path == null || !supported || tooBig) {
          skipped++;
          continue;
        }
        if (duplicate) continue;
        _pending.add(PendingFile(name: file.name, path: path, size: file.size));
      }
      _dirty = true;
    });
    if (skipped > 0) {
      showSnack(context, '$skipped file(s) skipped: only images and PDFs up to 25 MB each.');
    }
  }

  Future<void> _viewStored(DocumentFile file) async {
    final DocumentEntry? entry = widget.entry;
    if (entry == null) return;
    final int index = entry.files.indexWhere((DocumentFile f) => f.id == file.id);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => DocumentViewerPage(
          entry: entry,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_keptFiles.isEmpty && _pending.isEmpty) {
      showSnack(context, 'Add at least one image or PDF.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _progress = _pending.isEmpty ? 'Saving...' : 'Encrypting 1 / ${_pending.length}';
    });
    try {
      await ref.read(documentRepositoryProvider).save(
            existing: widget.entry,
            name: _name.text.trim(),
            userId: _userId.text.trim(),
            url: _url.text.trim(),
            password: _password.text,
            notes: _notes.text,
            newFiles: List<PendingFile>.of(_pending),
            removedFileIds: Set<String>.of(_removed),
            onProgress: (int done, int total) {
              // Encrypting many files counts as activity (no inactivity lock).
              reportUserActivity();
              if (!mounted) return;
              setState(() {
                _progress = done >= total ? 'Saving...' : 'Encrypting ${done + 1} / $total';
              });
            },
          );
      ref.invalidate(documentListProvider);
      await TempCleaner.clear();
      if (!mounted) return;
      _dirty = false;
      Navigator.of(context).pop();
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Could not save: $e');
    }
  }

  Future<void> _delete() async {
    final DocumentEntry? existing = widget.entry;
    if (existing == null) return;
    final bool confirmed = await confirmAction(
      context,
      title: 'Delete document?',
      message: 'Delete "${existing.name}" and its ${existing.files.length} file(s) permanently?',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(documentRepositoryProvider).delete(existing);
      ref.invalidate(documentListProvider);
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

  Future<void> _copyUserId() async {
    if (_userId.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _userId.text));
    if (!mounted) return;
    showSnack(context, 'User ID copied.');
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
    final List<DocumentFile> kept = _keptFiles;
    final bool hasFiles = kept.isNotEmpty || _pending.isNotEmpty;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || _saving) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: BrutalAppBar(
          title: _isNew ? 'Add document' : 'Document',
          actions: <Widget>[
            if (!_isNew)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving ? null : _delete,
              ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const SectionLabel('Document'),
                  VaultTextField(
                    controller: _name,
                    label: 'Name',
                    hint: 'e.g. Passport, Aadhaar, Bank statement',
                    prefixIcon: Icons.badge_outlined,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => _changed(),
                    validator: (String? v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel('Files'),
                  if (!hasFiles)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        'No files yet. You can add several photos or PDFs to one document.',
                        style: AppStyle.muted,
                      ),
                    ),
                  for (final DocumentFile file in kept)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileRow(
                        name: file.name,
                        kind: file.kind,
                        size: file.size,
                        isNew: false,
                        onView: () => _viewStored(file),
                        onRemove: () => setState(() {
                          _removed.add(file.id);
                          _dirty = true;
                        }),
                      ),
                    ),
                  for (final PendingFile file in _pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileRow(
                        name: file.name,
                        kind: DocumentKind.fromFileName(file.name) ?? DocumentKind.image,
                        size: file.size,
                        isNew: true,
                        onRemove: () => setState(() {
                          _pending.remove(file);
                          _dirty = true;
                        }),
                      ),
                    ),
                  const SizedBox(height: 4),
                  BrutalButton(
                    label: 'Add images / PDF',
                    icon: Icons.add_photo_alternate_outlined,
                    style: BrutalButtonStyle.outline,
                    onPressed: _saving ? null : _pickFiles,
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel('Details (optional)'),
                  VaultTextField(
                    controller: _userId,
                    label: 'User ID',
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _changed(),
                    suffix: IconButton(
                      tooltip: 'Copy User ID',
                      icon: const Icon(Icons.copy),
                      onPressed: _copyUserId,
                    ),
                  ),
                  const SizedBox(height: 20),
                  VaultTextField(
                    controller: _url,
                    label: 'URL',
                    hint: 'https://',
                    prefixIcon: Icons.link,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => _changed(),
                  ),
                  const SizedBox(height: 20),
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
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        IconButton(
                          tooltip: 'Copy password',
                          icon: const Icon(Icons.copy),
                          onPressed: _copyPassword,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  VaultTextField(
                    controller: _notes,
                    label: 'Note',
                    prefixIcon: Icons.notes,
                    maxLines: null,
                    minLines: 3,
                    onChanged: (_) => _changed(),
                  ),
                  const SizedBox(height: 28),
                  BrutalButton(
                    label: _isNew ? 'Save document' : 'Save changes',
                    icon: Icons.check,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (_saving) Positioned.fill(child: _SavingOverlay(text: _progress)),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.name,
    required this.kind,
    required this.size,
    required this.isNew,
    required this.onRemove,
    this.onView,
  });

  final String name;
  final DocumentKind kind;
  final int size;
  final bool isNew;
  final VoidCallback onRemove;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return BrutalTile(
      leading: IconBox(
        icon: kind == DocumentKind.pdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
        color: isNew ? AppColors.accent : AppColors.ink,
      ),
      title: name,
      titleSuffix: isNew ? const StatusTag('new') : null,
      subtitle: '${kind.label}  -  ${formatBytes(size)}',
      onTap: onView,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onView != null)
            IconButton(
              tooltip: 'Open',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: onView,
            ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const ModalBarrier(dismissible: false, color: Color(0xD9000000)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: BrutalCard(
              shadowColor: AppColors.accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    text.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 14),
                  const BrutalProgressBar(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
