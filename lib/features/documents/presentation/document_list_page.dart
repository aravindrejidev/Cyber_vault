import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/documents/domain/document_entry.dart';
import 'package:cyber_vault/features/documents/presentation/document_edit_page.dart';
import 'package:cyber_vault/features/documents/presentation/document_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentListPage extends ConsumerStatefulWidget {
  const DocumentListPage({super.key});

  @override
  ConsumerState<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends ConsumerState<DocumentListPage> {
  String _query = '';

  Future<void> _open([DocumentEntry? entry]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => DocumentEditPage(entry: entry),
      ),
    );
  }

  Future<void> _delete(DocumentEntry entry) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Delete document?',
      message: 'Delete "${entry.name}" and its ${entry.files.length} file(s) permanently?',
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
    return items.where((DocumentEntry e) {
      return e.name.toLowerCase().contains(q) ||
          e.userId.toLowerCase().contains(q) ||
          e.url.toLowerCase().contains(q) ||
          e.notes.toLowerCase().contains(q) ||
          e.files.any((DocumentFile f) => f.name.toLowerCase().contains(q));
    }).toList();
  }

  IconData _iconFor(DocumentEntry entry) {
    if (entry.files.length > 1) return Icons.photo_library_outlined;
    if (entry.files.isNotEmpty && entry.files.first.kind == DocumentKind.pdf) {
      return Icons.picture_as_pdf_outlined;
    }
    return Icons.image_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DocumentEntry>> documents = ref.watch(documentListProvider);
    final int? count = documents.maybeWhen(
      data: (List<DocumentEntry> items) => items.length,
      orElse: () => null,
    );

    return Scaffold(
      appBar: BrutalAppBar(title: 'Documents', actions: <Widget>[CountTag(count)]),
      floatingActionButton: BrutalButton(
        label: 'Add document',
        icon: Icons.note_add_outlined,
        expand: false,
        onPressed: () => _open(),
      ),
      body: Column(
        children: <Widget>[
          SearchField(
            hint: 'Search documents',
            onChanged: (String v) => setState(() => _query = v),
          ),
          Expanded(
            child: documents.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) =>
                  Center(child: ErrorBox('Could not load documents: $e')),
              data: (List<DocumentEntry> items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No documents yet',
                    message:
                        'Tap ADD DOCUMENT to store IDs, certificates or statements. Every file is encrypted with AES-256 before it is saved.',
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 12, 110),
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext c, int i) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext c, int i) {
                    final DocumentEntry entry = visible[i];
                    final int n = entry.files.length;
                    final String fileText = n == 1 ? '1 file' : '$n files';
                    return BrutalTile(
                      leading: IconBox(icon: _iconFor(entry)),
                      title: entry.name,
                      subtitle:
                          '$fileText  -  ${formatBytes(entry.totalSize)}  -  ${formatDate(entry.createdAt)}',
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(entry),
                      ),
                      onTap: () => _open(entry),
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
