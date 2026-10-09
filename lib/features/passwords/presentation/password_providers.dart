import 'package:cyber_vault/core/security/session.dart';
import 'package:cyber_vault/features/passwords/data/password_repository.dart';
import 'package:cyber_vault/features/passwords/domain/password_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<PasswordRepository> passwordRepositoryProvider =
    Provider<PasswordRepository>((ref) {
  // Rebuild when the vault locks/unlocks so a stale database is never used.
  ref.watch(sessionProvider.select((SessionState s) => s.status));
  final db = ref.read(sessionProvider.notifier).database;
  if (db == null) {
    throw StateError('The vault is locked.');
  }
  return PasswordRepository(db.raw);
});

/// Auto-disposed: the decrypted list is dropped as soon as no screen shows it
/// (for example when the vault locks).
final passwordListProvider =
    FutureProvider.autoDispose<List<PasswordEntry>>((ref) async {
  final PasswordRepository repository = ref.watch(passwordRepositoryProvider);
  return repository.getAll();
});
