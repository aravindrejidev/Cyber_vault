import 'dart:typed_data';

import 'package:cyber_vault/core/security/session.dart';
import 'package:cyber_vault/features/documents/data/document_repository.dart';
import 'package:cyber_vault/features/documents/domain/document_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<DocumentRepository> documentRepositoryProvider =
    Provider<DocumentRepository>((ref) {
  ref.watch(sessionProvider.select((SessionState s) => s.status));
  final SessionNotifier session = ref.read(sessionProvider.notifier);
  final db = session.database;
  if (db == null) {
    throw StateError('The vault is locked.');
  }
  return DocumentRepository(
    db: db.raw,
    storage: ref.read(vaultStorageProvider),
    keyProvider: () {
      final Uint8List? key = session.fileKey;
      if (key == null) {
        throw StateError('The vault is locked.');
      }
      return key;
    },
  );
});

/// Auto-disposed so the document list leaves RAM when the vault locks.
final documentListProvider =
    FutureProvider.autoDispose<List<DocumentEntry>>((ref) async {
  final DocumentRepository repository = ref.watch(documentRepositoryProvider);
  return repository.getAll();
});
