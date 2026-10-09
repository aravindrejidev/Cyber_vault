import 'package:cyber_vault/features/passwords/domain/password_entry.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class PasswordRepository {
  PasswordRepository(this._db);

  final Database _db;

  Future<List<PasswordEntry>> getAll() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'passwords',
      orderBy: 'favorite DESC, title COLLATE NOCASE ASC',
    );
    return rows.map(PasswordEntry.fromMap).toList();
  }

  Future<void> upsert(PasswordEntry entry) async {
    await _db.insert(
      'passwords',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await _db.delete(
      'passwords',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
