import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cyber_vault/core/crypto/crypto_service.dart';
import 'package:cyber_vault/core/crypto/vault_header.dart';
import 'package:cyber_vault/core/database/vault_database.dart';
import 'package:cyber_vault/core/database/vault_storage.dart';
import 'package:cyber_vault/core/security/biometric_service.dart';
import 'package:cyber_vault/core/security/clipboard_guard.dart';
import 'package:cyber_vault/core/security/temp_cleaner.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VaultStatus { loading, needsSetup, locked, unlocked, error }

/// A problem we can show to the user as-is.
class VaultException implements Exception {
  const VaultException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionState {
  const SessionState({
    this.status = VaultStatus.loading,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
    this.errorMessage,
  });

  final VaultStatus status;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final String? errorMessage;

  SessionState copyWith({
    VaultStatus? status,
    bool? biometricAvailable,
    bool? biometricEnabled,
  }) {
    return SessionState(
      status: status ?? this.status,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}

final Provider<VaultStorage> vaultStorageProvider =
    Provider<VaultStorage>((ref) => VaultStorage());

final Provider<BiometricService> biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());

final NotifierProvider<SessionNotifier, SessionState> sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// The only place where key material lives. The master password is never
/// stored; the MEK exists in RAM only while the vault is unlocked.
class SessionNotifier extends Notifier<SessionState> {
  Uint8List? _mek;
  Uint8List? _fileKey;
  VaultDatabase? _database;
  int _failedAttempts = 0;
  DateTime? _blockedUntil;

  VaultStorage get _storage => ref.read(vaultStorageProvider);
  BiometricService get _biometric => ref.read(biometricServiceProvider);

  /// The open encrypted database (null while locked).
  VaultDatabase? get database => _database;

  /// Key used for document blobs (null while locked).
  Uint8List? get fileKey => _fileKey;

  @override
  SessionState build() {
    ref.onDispose(_wipeKeys);
    Future<void>.microtask(initialize);
    return const SessionState();
  }

  Future<void> initialize() async {
    state = const SessionState();
    try {
      await TempCleaner.clear();
      final bool hasVault = await _storage.hasVault();
      final bool available = await _biometric.isAvailable();
      final bool enabled =
          hasVault && available && await _biometric.hasStoredKey();
      state = SessionState(
        status: hasVault ? VaultStatus.locked : VaultStatus.needsSetup,
        biometricAvailable: available,
        biometricEnabled: enabled,
      );
    } catch (e) {
      state = SessionState(
        status: VaultStatus.error,
        errorMessage: 'Could not read the vault storage: $e',
      );
    }
  }

  /// First-time setup: creates the master key, header and empty database.
  Future<void> createVault(String password) async {
    if (await _storage.hasVault()) {
      throw const VaultException('A vault already exists on this device.');
    }
    // Remove leftovers of an interrupted earlier setup.
    await _storage.wipeAll();

    final Uint8List salt = CryptoService.randomBytes(CryptoService.saltLength);
    final Uint8List mek = CryptoService.randomBytes(CryptoService.keyLength);
    const KdfParams params = KdfParams.standard;

    final Uint8List kek = await CryptoService.deriveKek(password, salt, params);
    final Uint8List wrapped = await CryptoService.wrapKey(mek, kek)
        .whenComplete(() => CryptoService.wipe(kek));

    await _openSession(
      mek,
      newHeader: VaultHeader(kdf: params, salt: salt, wrappedMek: wrapped),
    );
  }

  /// Returns false when the password is wrong.
  Future<bool> unlockWithPassword(String password) async {
    final DateTime now = DateTime.now();
    final DateTime? blockedUntil = _blockedUntil;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      final int seconds = blockedUntil.difference(now).inSeconds + 1;
      throw VaultException('Too many attempts. Try again in $seconds s.');
    }

    final VaultHeader header = await _storage.readHeader();
    final Uint8List kek =
        await CryptoService.deriveKek(password, header.salt, header.kdf);
    Uint8List? mek;
    try {
      mek = await CryptoService.unwrapKey(header.wrappedMek, kek);
    } on CryptoException {
      mek = null;
    } finally {
      CryptoService.wipe(kek);
    }
    if (mek == null) {
      _registerFailure();
      return false;
    }
    await _openSession(mek);
    return true;
  }

  /// Returns false when the check was cancelled or no key is stored.
  Future<bool> unlockWithBiometrics() async {
    if (!state.biometricEnabled || state.status != VaultStatus.locked) {
      return false;
    }
    final bool ok = await _biometric.authenticate('Unlock Cyber Vault');
    if (!ok) return false;
    final Uint8List? mek = await _biometric.readKey();
    if (mek == null) {
      state = state.copyWith(biometricEnabled: false);
      return false;
    }
    await _openSession(mek);
    return true;
  }

  /// Purges all key material from RAM and closes the database.
  Future<void> lock() async {
    if (state.status != VaultStatus.unlocked) return;
    final VaultDatabase? db = _database;
    _database = null;
    _wipeKeys();
    state = state.copyWith(status: VaultStatus.locked);
    _dropDecodedImages();
    await ClipboardGuard.clearNow();
    await TempCleaner.clear();
    try {
      await db?.close();
    } catch (_) {
      // Already closed.
    }
  }

  /// Re-wraps the same MEK under a new password. Data is not re-encrypted.
  /// Returns false when [oldPassword] is wrong.
  Future<bool> changeMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    if (state.status != VaultStatus.unlocked) {
      throw const VaultException('Unlock the vault first.');
    }
    final VaultHeader header = await _storage.readHeader();
    final Uint8List oldKek =
        await CryptoService.deriveKek(oldPassword, header.salt, header.kdf);
    Uint8List? mek;
    try {
      mek = await CryptoService.unwrapKey(header.wrappedMek, oldKek);
    } on CryptoException {
      mek = null;
    } finally {
      CryptoService.wipe(oldKek);
    }
    if (mek == null) return false;

    final Uint8List salt = CryptoService.randomBytes(CryptoService.saltLength);
    const KdfParams params = KdfParams.standard;
    final Uint8List newKek =
        await CryptoService.deriveKek(newPassword, salt, params);
    try {
      final Uint8List wrapped = await CryptoService.wrapKey(mek, newKek);
      await _storage.writeHeader(
        VaultHeader(kdf: params, salt: salt, wrappedMek: wrapped),
      );
    } finally {
      CryptoService.wipe(newKek);
      CryptoService.wipe(mek);
    }
    return true;
  }

  /// Returns an error message, or null on success.
  Future<String?> setBiometricEnabled(bool enabled) async {
    final Uint8List? mek = _mek;
    if (state.status != VaultStatus.unlocked || mek == null) {
      return 'The vault is locked.';
    }
    if (enabled) {
      if (!await _biometric.isAvailable()) {
        return 'No biometrics are enrolled on this device.';
      }
      final bool ok = await _biometric.authenticate('Enable biometric unlock');
      if (!ok) return 'Biometric check was cancelled.';
      await _biometric.storeKey(mek);
    } else {
      await _biometric.clearKey();
    }
    state = state.copyWith(biometricEnabled: enabled);
    return null;
  }

  /// Deletes EVERYTHING (header, database, encrypted files, biometric key).
  Future<void> eraseVault() async {
    final VaultDatabase? db = _database;
    _database = null;
    _wipeKeys();
    try {
      await db?.close();
    } catch (_) {
      // Already closed.
    }
    await _biometric.clearKey();
    await _storage.wipeAll();
    await ClipboardGuard.clearNow();
    await TempCleaner.clear();
    _dropDecodedImages();
    _failedAttempts = 0;
    _blockedUntil = null;
    state = SessionState(
      status: VaultStatus.needsSetup,
      biometricAvailable: state.biometricAvailable,
    );
  }

  Future<void> _openSession(Uint8List mek, {VaultHeader? newHeader}) async {
    Uint8List? dbKey;
    Uint8List? fileKey;
    VaultDatabase? db;
    try {
      dbKey = await CryptoService.deriveSubKey(mek, 'cybervault/db/v1');
      fileKey = await CryptoService.deriveSubKey(mek, 'cybervault/files/v1');
      db = await VaultDatabase.open(
        path: await _storage.databasePath(),
        passphrase: CryptoService.toHex(dbKey),
      );
      if (newHeader != null) {
        await _storage.writeHeader(newHeader);
      }
    } catch (e) {
      CryptoService.wipe(mek);
      CryptoService.wipe(fileKey);
      try {
        await db?.close();
      } catch (_) {
        // Ignore.
      }
      throw VaultException('Could not open the vault: $e');
    } finally {
      CryptoService.wipe(dbKey);
    }

    _mek = mek;
    _fileKey = fileKey;
    _database = db;
    _failedAttempts = 0;
    _blockedUntil = null;
    state = state.copyWith(status: VaultStatus.unlocked);
  }

  void _registerFailure() {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      final int step = math.min(_failedAttempts - 5, 4);
      final int seconds = math.min(300, 30 * (1 << step));
      _blockedUntil = DateTime.now().add(Duration(seconds: seconds));
    }
  }

  void _wipeKeys() {
    CryptoService.wipe(_mek);
    CryptoService.wipe(_fileKey);
    _mek = null;
    _fileKey = null;
  }

  void _dropDecodedImages() {
    final ImageCache cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }
}
