import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Thrown when data cannot be decrypted or authenticated.
class CryptoException implements Exception {
  const CryptoException(this.message);

  final String message;

  @override
  String toString() => 'CryptoException: $message';
}

/// Argon2id cost parameters. They are stored in the vault header, so they can
/// be raised in a future version without breaking existing vaults.
class KdfParams {
  const KdfParams({
    this.memoryKiB = 19456,
    this.iterations = 2,
    this.parallelism = 1,
  });

  /// OWASP minimum recommendation: 19 MiB memory, 2 iterations, 1 lane.
  static const KdfParams standard = KdfParams();

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  bool get isSane =>
      memoryKiB >= 1024 &&
      memoryKiB <= 1048576 &&
      iterations >= 1 &&
      iterations <= 20 &&
      parallelism >= 1 &&
      parallelism <= 8;
}

/// All cryptography of the vault lives here.
///
/// Key hierarchy:
///   master password --Argon2id--> KEK (derived in RAM, never stored)
///   random 256-bit MEK --AES-256-GCM(KEK)--> wrapped MEK (stored in header)
///   MEK --HKDF-SHA256--> database key, file key
class CryptoService {
  CryptoService._();

  static const int keyLength = 32;
  static const int saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  static final Random _random = Random.secure();
  static final AesGcm _aes = AesGcm.with256bits();
  static final List<int> _wrapAad = utf8.encode('cybervault/mek-wrap/v1');
  static final List<int> _hkdfSalt = utf8.encode('cybervault/hkdf-salt/v1');

  /// Cryptographically secure random bytes.
  static Uint8List randomBytes(int length) {
    final Uint8List out = Uint8List(length);
    for (int i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  /// 128-bit random identifier as hex.
  static String newId() => toHex(randomBytes(16));

  static String toHex(List<int> bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Best-effort zeroing of key material. Dart's garbage collector may still
  /// hold copies, but this removes every reference we control.
  static void wipe(Uint8List? bytes) {
    if (bytes == null) return;
    bytes.fillRange(0, bytes.length, 0);
  }

  /// Derives the key-encryption key from the master password (Argon2id).
  /// Runs in a background isolate so the UI stays responsive.
  static Future<Uint8List> deriveKek(
    String password,
    Uint8List salt,
    KdfParams params,
  ) async {
    final Uint8List passwordBytes = Uint8List.fromList(utf8.encode(password));
    try {
      return await Isolate.run<Uint8List>(() async {
        final Argon2id algorithm = Argon2id(
          memory: params.memoryKiB,
          parallelism: params.parallelism,
          iterations: params.iterations,
          hashLength: keyLength,
        );
        final SecretKey key = await algorithm.deriveKey(
          secretKey: SecretKey(passwordBytes),
          nonce: salt,
        );
        return Uint8List.fromList(await key.extractBytes());
      });
    } finally {
      wipe(passwordBytes);
    }
  }

  /// AES-256-GCM. Output layout: nonce(12) + ciphertext + tag(16).
  static Future<Uint8List> encrypt(
    Uint8List clear,
    Uint8List key, {
    List<int> aad = const <int>[],
  }) async {
    if (key.length != keyLength) {
      throw const CryptoException('Invalid key length.');
    }
    final SecretBox box = await _aes.encrypt(
      clear,
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(box.concatenation());
  }

  static Future<Uint8List> decrypt(
    Uint8List blob,
    Uint8List key, {
    List<int> aad = const <int>[],
  }) async {
    if (key.length != keyLength) {
      throw const CryptoException('Invalid key length.');
    }
    if (blob.length < _nonceLength + _macLength) {
      throw const CryptoException('Encrypted data is too short.');
    }
    try {
      final SecretBox box = SecretBox.fromConcatenation(
        blob,
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      final List<int> clear = await _aes.decrypt(
        box,
        secretKey: SecretKey(key),
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const CryptoException('Wrong key or corrupted data.');
    }
  }

  /// Same as [encrypt] but off the UI isolate (use for files).
  static Future<Uint8List> encryptInBackground(
    Uint8List clear,
    Uint8List key, {
    String aad = '',
  }) {
    return Isolate.run<Uint8List>(
      () => encrypt(clear, key, aad: utf8.encode(aad)),
    );
  }

  /// Same as [decrypt] but off the UI isolate (use for files).
  static Future<Uint8List> decryptInBackground(
    Uint8List blob,
    Uint8List key, {
    String aad = '',
  }) {
    return Isolate.run<Uint8List>(
      () => decrypt(blob, key, aad: utf8.encode(aad)),
    );
  }

  /// Wraps (encrypts) the master encryption key with the KEK.
  static Future<Uint8List> wrapKey(Uint8List mek, Uint8List kek) {
    return encrypt(mek, kek, aad: _wrapAad);
  }

  /// Unwraps the MEK. Throws [CryptoException] when the password was wrong.
  static Future<Uint8List> unwrapKey(Uint8List wrapped, Uint8List kek) {
    return decrypt(wrapped, kek, aad: _wrapAad);
  }

  /// Derives an independent 256-bit sub-key from the MEK (HKDF-SHA256).
  static Future<Uint8List> deriveSubKey(Uint8List mek, String label) async {
    final Hkdf hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: keyLength);
    final SecretKey key = await hkdf.deriveKey(
      secretKey: SecretKey(mek),
      nonce: _hkdfSalt,
      info: utf8.encode(label),
    );
    return Uint8List.fromList(await key.extractBytes());
  }
}
