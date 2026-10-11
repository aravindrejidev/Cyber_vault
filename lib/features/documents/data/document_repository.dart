import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_vault/core/crypto/crypto_service.dart';
import 'package:cyber_vault/core/database/vault_storage.dart';
import 'package:cyber_vault/features/documents/domain/document_entry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// A file the user picked that is not encrypted / stored yet. [path] points to
/// the file picker's cache copy, which is deleted once the document is saved.
class PendingFile {
  const PendingFile({
    required this.name,
    required this.path,
    required this.size,
  });

  final String name;
  final String path;
  final int size;
}

/// Stores every file as an AES-256-GCM encrypted blob inside the app-private
/// directory. Decrypted bytes only ever exist in memory; nothing decrypted is
/// written to disk. Each blob is bound to its file id (GCM associated data),
/// so blobs cannot be swapped between records.
class DocumentRepository {
  DocumentRepository({
    required Database db,
    required VaultStorage storage,
    required Uint8List Function() keyProvider,
  })  : _db = db,
        _storage = storage,
        _keyProvider = keyProvider;

  /// Per file. Files are processed one at a time in memory.
  static const int maxFileBytes = 25 * 1024 * 1024;

  final Database _db;
  final VaultStorage _storage;
  final Uint8List Function() _keyProvider;

  Future<List<DocumentEntry>> getAll() async {
    final List<Map<String, Object?>> documentRows = await _db.query(
      'documents',
      orderBy: 'created_at DESC',
    );
    final List<Map<String, Object?>> fileRows = await _db.query(
      'document_files',
      orderBy: 'document_id ASC, position ASC',
    );

    final Map<String, List<DocumentFile>> byDocument =
        <String, List<DocumentFile>>{};
    for (final Map<String, Object?> row in fileRows) {
      final DocumentFile file = DocumentFile.fromMap(row);
      byDocument
          .putIfAbsent(file.documentId, () => <DocumentFile>[])
          .add(file);
    }

    return documentRows.map((Map<String, Object?> row) {
      final String id = row['id']! as String;
      return DocumentEntry.fromMap(
        row,
        byDocument[id] ?? const <DocumentFile>[],
      );
    }).toList();
  }

  /// Creates a document ([existing] == null) or updates one. New files are
  /// encrypted one by one; [removedFileIds] are deleted after the metadata is
  /// committed. If anything fails, newly written blobs are removed again.
  Future<DocumentEntry> save({
    DocumentEntry? existing,
    required String name,
    required String userId,
    required String url,
    required String password,
    required String notes,
    required List<PendingFile> newFiles,
    required Set<String> removedFileIds,
    void Function(int done, int total)? onProgress,
  }) async {
    final List<DocumentFile> oldFiles =
        existing?.files ?? const <DocumentFile>[];
    final List<DocumentFile> kept = oldFiles
        .where((DocumentFile f) => !removedFileIds.contains(f.id))
        .toList();
    final List<DocumentFile> removed = oldFiles
        .where((DocumentFile f) => removedFileIds.contains(f.id))
        .toList();
    if (kept.isEmpty && newFiles.isEmpty) {
      throw const FormatException('Add at least one image or PDF.');
    }

    final String documentId = existing?.id ?? CryptoService.newId();
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<DocumentFile> added = <DocumentFile>[];

    try {
      for (int i = 0; i < newFiles.length; i++) {
        onProgress?.call(i, newFiles.length);
        added.add(await _storeFile(documentId, newFiles[i], now));
      }
      onProgress?.call(newFiles.length, newFiles.length);

      final List<DocumentFile> files = <DocumentFile>[];
      for (final DocumentFile file in <DocumentFile>[...kept, ...added]) {
        files.add(file.withPosition(files.length));
      }
      final DocumentEntry entry = DocumentEntry(
        id: documentId,
        name: name,
        userId: userId,
        url: url,
        password: password,
        notes: notes,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        files: files,
      );

      await _db.transaction((Transaction txn) async {
        if (existing == null) {
          await txn.insert('documents', entry.toMap());
        } else {
          await txn.update(
            'documents',
            entry.toMap(),
            where: 'id = ?',
            whereArgs: <Object?>[documentId],
          );
        }
        for (final DocumentFile file in removed) {
          await txn.delete(
            'document_files',
            where: 'id = ?',
            whereArgs: <Object?>[file.id],
          );
        }
        for (final DocumentFile file in files) {
          await txn.insert(
            'document_files',
            file.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      // The metadata is committed: the removed blobs can go. Errors here must
      // never undo anything.
      for (final DocumentFile file in removed) {
        await _deleteBlobQuiet(file.blobName);
      }
      return entry;
    } catch (_) {
      for (final DocumentFile file in added) {
        await _deleteBlobQuiet(file.blobName);
      }
      rethrow;
    }
  }

  /// Decrypts one file into memory. The caller must wipe the result when done
  /// (see CryptoService.wipe).
  Future<Uint8List> readFileBytes(DocumentFile file) async {
    final Directory dir = await _storage.documentsDir();
    final Uint8List encrypted =
        await File(p.join(dir.path, file.blobName)).readAsBytes();
    return CryptoService.decryptInBackground(
      encrypted,
      _keyProvider(),
      aad: 'doc:${file.id}',
    );
  }

  Future<void> delete(DocumentEntry entry) async {
    await _db.transaction((Transaction txn) async {
      await txn.delete(
        'document_files',
        where: 'document_id = ?',
        whereArgs: <Object?>[entry.id],
      );
      await txn.delete(
        'documents',
        where: 'id = ?',
        whereArgs: <Object?>[entry.id],
      );
    });
    for (final DocumentFile file in entry.files) {
      await _deleteBlobQuiet(file.blobName);
    }
  }

  Future<DocumentFile> _storeFile(
    String documentId,
    PendingFile pending,
    int now,
  ) async {
    final DocumentKind? kind = DocumentKind.fromFileName(pending.name);
    if (kind == null) {
      throw FormatException('"${pending.name}" is not an image or a PDF.');
    }
    final File source = File(pending.path);
    final int length = await source.length();
    if (length > maxFileBytes) {
      throw FormatException('"${pending.name}" is larger than 25 MB.');
    }

    final String fileId = CryptoService.newId();
    final String blobName = '$fileId.vlt';

    final Uint8List plain = await source.readAsBytes();
    final Uint8List encrypted;
    try {
      encrypted = await CryptoService.encryptInBackground(
        plain,
        _keyProvider(),
        aad: 'doc:$fileId',
      );
    } finally {
      CryptoService.wipe(plain);
    }

    final Directory dir = await _storage.documentsDir();
    final File target = File(p.join(dir.path, blobName));
    final File temp = File('${target.path}.part');
    await temp.writeAsBytes(encrypted, flush: true);
    await temp.rename(target.path);

    return DocumentFile(
      id: fileId,
      documentId: documentId,
      name: pending.name,
      kind: kind,
      size: length,
      blobName: blobName,
      position: 0,
      createdAt: now,
    );
  }

  Future<void> _deleteBlobQuiet(String blobName) async {
    try {
      final Directory dir = await _storage.documentsDir();
      final File file = File(p.join(dir.path, blobName));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort only.
    }
  }
}
