import 'package:sqflite_sqlcipher/sqflite.dart';

/// Encrypted (SQLCipher, AES-256) structured storage for passwords, notes and
/// documents. The passphrase is derived from the MEK and exists only while the
/// vault is unlocked.
class VaultDatabase {
  VaultDatabase._(this.raw);

  final Database raw;

  /// 1: passwords, notes, documents (exactly one file each)
  /// 2: documents get User ID / URL / password / note and can hold many files
  static const int _schemaVersion = 2;

  static Future<VaultDatabase> open({
    required String path,
    required String passphrase,
  }) async {
    final Database db = await openDatabase(
      path,
      password: passphrase,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return VaultDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE passwords (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        username TEXT NOT NULL DEFAULT '',
        password TEXT NOT NULL DEFAULT '',
        url TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await _createDocuments(db, 'documents');
    await _createDocumentFiles(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Version 1 kept exactly one file inside every documents row. Each old
      // document becomes a version-2 document with one file. The file keeps
      // the old id, so its encrypted blob (which is bound to that id) still
      // decrypts and nothing has to be re-encrypted.
      await _createDocuments(db, 'documents_v2');
      await _createDocumentFiles(db);
      await db.execute('''
        INSERT INTO documents_v2 (id, name, created_at, updated_at)
        SELECT id, name, created_at, created_at FROM documents
      ''');
      await db.execute('''
        INSERT INTO document_files
          (id, document_id, name, kind, size, blob_name, position, created_at)
        SELECT id, id, name, kind, size, blob_name, 0, created_at FROM documents
      ''');
      await db.execute('DROP TABLE documents');
      await db.execute('ALTER TABLE documents_v2 RENAME TO documents');
    }
  }

  static Future<void> _createDocuments(Database db, String table) {
    return db.execute('''
      CREATE TABLE $table (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        user_id TEXT NOT NULL DEFAULT '',
        url TEXT NOT NULL DEFAULT '',
        password TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createDocumentFiles(Database db) async {
    await db.execute('''
      CREATE TABLE document_files (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        size INTEGER NOT NULL,
        blob_name TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_document_files_document ON document_files (document_id)',
    );
  }

  Future<void> close() => raw.close();
}
