import 'package:cyber_vault/core/theme/app_theme.dart';
import 'package:cyber_vault/core/widgets/common_widgets.dart';
import 'package:cyber_vault/features/notes/domain/note_entry.dart';
import 'package:cyber_vault/features/notes/presentation/note_edit_page.dart';
import 'package:cyber_vault/features/notes/presentation/note_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteListPage extends ConsumerStatefulWidget {
  const NoteListPage({super.key});

  @override
  ConsumerState<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends ConsumerState<NoteListPage> {
  String _query = '';

  Future<void> _open([NoteEntry? note]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => NoteEditPage(note: note),
      ),
    );
  }

  List<NoteEntry> _filter(List<NoteEntry> items) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((NoteEntry n) =>
            n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
        .toList();
  }

  String _preview(String body) {
    final String flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.isEmpty ? 'No text' : flat;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<NoteEntry>> notes = ref.watch(noteListProvider);
    final int? count = notes.maybeWhen(
      data: (List<NoteEntry> items) => items.length,
      orElse: () => null,
    );

    return Scaffold(
      appBar: BrutalAppBar(title: 'Notes', actions: <Widget>[CountTag(count)]),
      floatingActionButton: BrutalButton(
        label: 'New note',
        icon: Icons.add,
        expand: false,
        onPressed: () => _open(),
      ),
      body: Column(
        children: <Widget>[
          SearchField(
            hint: 'Search notes',
            onChanged: (String v) => setState(() => _query = v),
          ),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) =>
                  Center(child: ErrorBox('Could not load notes: $e')),
              data: (List<NoteEntry> items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'No notes yet',
                    message: 'Tap NEW NOTE to write something private.',
                  );
                }
                final List<NoteEntry> visible = _filter(items);
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
                    final NoteEntry note = visible[i];
                    return BrutalTile(
                      leading: const IconBox(icon: Icons.sticky_note_2_outlined),
                      title: note.title,
                      subtitle: _preview(note.body),
                      trailing: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          formatDate(note.updatedAt),
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ),
                      onTap: () => _open(note),
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
