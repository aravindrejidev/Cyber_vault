import 'package:cyber_vault/core/security/session.dart';
import 'package:cyber_vault/features/notes/data/note_repository.dart';
import 'package:cyber_vault/features/notes/domain/note_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<NoteRepository> noteRepositoryProvider =
    Provider<NoteRepository>((ref) {
  ref.watch(sessionProvider.select((SessionState s) => s.status));
  final db = ref.read(sessionProvider.notifier).database;
  if (db == null) {
    throw StateError('The vault is locked.');
  }
  return NoteRepository(db.raw);
});

/// Auto-disposed so decrypted notes leave RAM when the vault locks.
final noteListProvider =
    FutureProvider.autoDispose<List<NoteEntry>>((ref) async {
  final NoteRepository repository = ref.watch(noteRepositoryProvider);
  return repository.getAll();
});
