import 'dart:convert';
import 'dart:typed_data';

import 'package:cyber_vault/core/crypto/crypto_service.dart';

/// Everything needed to unlock the vault except the master password.
/// Contains no secret: the MEK is stored only in wrapped (encrypted) form.
class VaultHeader {
  const VaultHeader({
    required this.kdf,
    required this.salt,
    required this.wrappedMek,
    this.version = 1,
  });

  final int version;
  final KdfParams kdf;
  final Uint8List salt;
  final Uint8List wrappedMek;

  Map<String, Object> toJson() => <String, Object>{
        'version': version,
        'kdf': 'argon2id',
        'memoryKiB': kdf.memoryKiB,
        'iterations': kdf.iterations,
        'parallelism': kdf.parallelism,
        'salt': base64Encode(salt),
        'wrappedMek': base64Encode(wrappedMek),
      };

  factory VaultHeader.fromJson(Map<String, dynamic> json) {
    if (json['kdf'] != 'argon2id') {
      throw const FormatException('Unsupported key derivation function.');
    }
    final KdfParams params = KdfParams(
      memoryKiB: json['memoryKiB'] as int,
      iterations: json['iterations'] as int,
      parallelism: json['parallelism'] as int,
    );
    if (!params.isSane) {
      throw const FormatException('Invalid key derivation parameters.');
    }
    return VaultHeader(
      version: json['version'] as int,
      kdf: params,
      salt: base64Decode(json['salt'] as String),
      wrappedMek: base64Decode(json['wrappedMek'] as String),
    );
  }
}
