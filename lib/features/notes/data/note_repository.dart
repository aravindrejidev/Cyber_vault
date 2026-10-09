import 'package:cyber_vault/features/notes/domain/note_entry.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class NoteRepository {
  NoteRepository(this._db);

  final Database _db;

  Future<List<NoteEntry>> getAll() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return rows.map(NoteEntry.fromMap).toList();
  }

  Future<void> upsert(NoteEntry note) async {
    await _db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await _db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
