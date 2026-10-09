import 'dart:convert';
import 'dart:io';

import 'package:cyber_vault/core/crypto/vault_header.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the vault's files. Everything lives in the app-private support
/// directory (not reachable by other apps, excluded from backups).
class VaultStorage {
  Directory? _root;

  Future<Directory> _rootDir() async {
    final Directory? cached = _root;
    if (cached != null && await cached.exists()) return cached;
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(base.path, 'vault'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _root = dir;
    return dir;
  }

  Future<File> _headerFile() async {
    final Directory root = await _rootDir();
    return File(p.join(root.path, 'vault_header.json'));
  }

  Future<String> databasePath() async {
    final Directory root = await _rootDir();
    return p.join(root.path, 'vault.db');
  }

  /// Folder holding the AES-256-GCM encrypted document blobs.
  Future<Directory> documentsDir() async {
    final Directory root = await _rootDir();
    final Directory dir = Directory(p.join(root.path, 'files'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> hasVault() async {
    final File file = await _headerFile();
    return file.exists();
  }

  Future<VaultHeader> readHeader() async {
    final File file = await _headerFile();
    final String text = await file.readAsString();
    final Object? decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Vault header is corrupted.');
    }
    return VaultHeader.fromJson(decoded);
  }

  /// Atomic write: temp file first, then rename over the real header.
  Future<void> writeHeader(VaultHeader header) async {
    final File file = await _headerFile();
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(header.toJson()), flush: true);
    await temp.rename(file.path);
  }

  /// Deletes the header, database and every encrypted file.
  Future<void> wipeAll() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(base.path, 'vault'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _root = null;
  }
}
