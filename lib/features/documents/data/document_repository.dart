import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_vault/core/crypto/crypto_service.dart';
import 'package:cyber_vault/core/database/vault_storage.dart';
import 'package:cyber_vault/features/documents/domain/document_entry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Stores documents as AES-256-GCM encrypted blobs inside the app-private
/// directory. Decrypted bytes only ever exist in memory; nothing decrypted is
/// written to disk. Each blob is bound to its record id (GCM associated data),
/// so blobs cannot be swapped between records.
class DocumentRepository {
  DocumentRepository({
    required Database db,
    required VaultStorage storage,
    required Uint8List Function() keyProvider,
  })  : _db = db,
        _storage = storage,
        _keyProvider = keyProvider;

  /// Files are held in memory while encrypting/decrypting.
  static const int maxFileBytes = 25 * 1024 * 1024;

  final Database _db;
  final VaultStorage _storage;
  final Uint8List Function() _keyProvider;

  Future<List<DocumentEntry>> getAll() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'documents',
      orderBy: 'created_at DESC',
    );
    return rows.map(DocumentEntry.fromMap).toList();
  }

  Future<DocumentEntry> importFile({
    required String name,
    required Uint8List bytes,
  }) async {
    final DocumentKind? kind = DocumentKind.fromFileName(name);
    if (kind == null) {
      throw const FormatException('Only PDF and image files are supported.');
    }
    if (bytes.length > maxFileBytes) {
      throw const FormatException('Files larger than 25 MB are not supported.');
    }

    final String id = CryptoService.newId();
    final String blobName = '$id.vlt';
    final Uint8List encrypted = await CryptoService.encryptInBackground(
      bytes,
      _keyProvider(),
      aad: 'doc:$id',
    );

    final Directory dir = await _storage.documentsDir();
    final File target = File(p.join(dir.path, blobName));
    final File temp = File('${target.path}.part');
    await temp.writeAsBytes(encrypted, flush: true);
    await temp.rename(target.path);

    final DocumentEntry entry = DocumentEntry(
      id: id,
      name: name,
      kind: kind,
      size: bytes.length,
      blobName: blobName,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await _db.insert('documents', entry.toMap());
    } catch (_) {
      await _deleteBlob(blobName);
      rethrow;
    }
    return entry;
  }

  /// Decrypts a document into memory. The caller must wipe the result when
  /// done (see CryptoService.wipe).
  Future<Uint8List> readBytes(DocumentEntry entry) async {
    final Directory dir = await _storage.documentsDir();
    final File file = File(p.join(dir.path, entry.blobName));
    final Uint8List encrypted = await file.readAsBytes();
    return CryptoService.decryptInBackground(
      encrypted,
      _keyProvider(),
      aad: 'doc:${entry.id}',
    );
  }

  Future<void> rename(String id, String newName) async {
    await _db.update(
      'documents',
      <String, Object?>{'name': newName},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> delete(DocumentEntry entry) async {
    await _db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: <Object?>[entry.id],
    );
    await _deleteBlob(entry.blobName);
  }

  Future<void> _deleteBlob(String blobName) async {
    final Directory dir = await _storage.documentsDir();
    final File file = File(p.join(dir.path, blobName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
