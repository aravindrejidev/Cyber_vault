import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric unlock. When enabled, the MEK is kept in secure storage (backed
/// by the Android Keystore) and is released only after a successful biometric
/// check. Disabling biometrics deletes that copy.
class BiometricService {
  BiometricService();

  static const String _keyName = 'cybervault.biometric.mek';

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  /// True when the device has enrolled biometrics we can use.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasStoredKey() async {
    try {
      return await _storage.containsKey(key: _keyName);
    } catch (_) {
      return false;
    }
  }

  Future<void> storeKey(Uint8List mek) {
    return _storage.write(key: _keyName, value: base64Encode(mek));
  }

  Future<Uint8List?> readKey() async {
    final String? value = await _storage.read(key: _keyName);
    if (value == null) return null;
    return base64Decode(value);
  }

  Future<void> clearKey() async {
    try {
      await _storage.delete(key: _keyName);
    } catch (_) {
      // Nothing stored.
    }
  }
}
