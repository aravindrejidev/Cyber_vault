import 'dart:typed_data';

import 'package:cyber_vault/core/crypto/crypto_service.dart';
import 'package:cyber_vault/core/security/auto_lock.dart';
import 'package:cyber_vault/core/security/temp_cleaner.dart';
import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/documents/data/document_repository.dart';
import 'package:cyber_vault/features/documents/domain/document_entry.dart';
import 'package:cyber_vault/features/documents/presentation/document_providers.dart';
import 'package:cyber_vault/features/documents/presentation/document_viewer_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentListPage extends ConsumerStatefulWidget {
  const DocumentListPage({super.key});

  @override
  ConsumerState<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends ConsumerState<DocumentListPage> {
  String _query = '';
  bool _busy = false;

  Future<void> _import() async {
    if (_busy) return;
    final DocumentRepository repo = ref.read(documentRepositoryProvider);

    FilePickerResult? result;
    try {
      // The picker leaves the app; do not auto-lock while it is open.
      result = await LockGuard.suspendWhile<FilePickerResult?>(
        () => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: DocumentKind.supportedExtensions,
          withData: true,
          compressionQuality: 0,
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the file picker: $e');
      return;
    }

    if (result == null || result.files.isEmpty) {
      await TempCleaner.clear();
      return;
    }

    final PlatformFile picked = result.files.first;
    final Uint8List? bytes = picked.bytes;
    if (bytes == null) {
      await TempCleaner.clear();
      if (mounted) showSnack(context, 'Could not read that file.');
      return;
    }
    if (bytes.length > DocumentRepository.maxFileBytes) {
      CryptoService.wipe(bytes);
      await TempCleaner.clear();
      if (mounted) {
        showSnack(context, 'Files larger than 25 MB are not supported.');
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await repo.importFile(name: picked.name, bytes: bytes);
      ref.invalidate(documentListProvider);
      if (mounted) showSnack(context, 'Encrypted and stored in your vault.');
    } on FormatException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, 'Import failed: $e');
    } finally {
      // The plaintext copy and the picker's cache copy are removed right away.
      CryptoService.wipe(bytes);
      await TempCleaner.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(DocumentEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => DocumentViewerPage(entry: entry),
      ),
    );
  }

  Future<void> _rename(DocumentEntry entry) async {
    final String? name = await promptText(
      context,
      title: 'Rename document',
      label: 'Name',
      initial: entry.name,
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await ref.read(documentRepositoryProvider).rename(entry.id, name);
      ref.invalidate(documentListProvider);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not rename: $e');
    }
  }

  Future<void> _delete(DocumentEntry entry) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Delete document?',
      message: 'Delete "${entry.name}" permanently?',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(documentRepositoryProvider).delete(entry);
      ref.invalidate(documentListProvider);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not delete: $e');
    }
  }

  List<DocumentEntry> _filter(List<DocumentEntry> items) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((DocumentEntry e) => e.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DocumentEntry>> documents =
        ref.watch(documentListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _import,
        icon: const Icon(Icons.upload_file),
        label: const Text('Import'),
      ),
      body: Column(
        children: <Widget>[
          if (_busy) const LinearProgressIndicator(minHeight: 3),
          SearchField(
            hint: 'Search documents',
            onChanged: (String v) => setState(() => _query = v),
          ),
          Expanded(
            child: documents.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) =>
                  Center(child: Text('Could not load documents: $e')),
              data: (List<DocumentEntry> items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No documents yet',
                    message:
                        'Import PDFs or photos of your IDs. They are encrypted with AES-256 before they are saved.',
                  );
                }
                final List<DocumentEntry> visible = _filter(items);
                if (visible.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message: 'Try a different search.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext c, int i) =>
                      const SizedBox(height: 8),
                  itemBuilder: (BuildContext c, int i) {
                    final DocumentEntry entry = visible[i];
                    return NeonCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: Icon(
                          entry.kind == DocumentKind.pdf
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          color: AppColors.neonCyan,
                        ),
                        title: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${entry.kind.label} · ${formatBytes(entry.size)} · ${formatDate(entry.createdAt)}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (String value) {
                            if (value == 'rename') {
                              _rename(entry);
                            } else if (value == 'delete') {
                              _delete(entry);
                            }
                          },
                          itemBuilder: (BuildContext ctx) =>
                              const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                        onTap: () => _view(entry),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
