import 'package:flutter/services.dart';

/// Talks to MainActivity.kt: asks Android to install a downloaded APK.
/// Throws [PlatformException] when Android refuses.
class ApkInstaller {
  ApkInstaller._();

  static const MethodChannel _channel = MethodChannel('cybervault/installer');

  /// True when the user has allowed this app to install other APKs.
  static Future<bool> canInstall() async {
    return (await _channel.invokeMethod<bool>('canInstall')) ?? false;
  }

  /// Opens Android's "install unknown apps" screen for this app.
  static Future<void> openInstallSettings() async {
    await _channel.invokeMethod<bool>('openInstallSettings');
  }

  /// Opens the system installer for the APK at [path].
  static Future<void> install(String path) async {
    await _channel.invokeMethod<bool>(
      'install',
      <String, Object?>{'path': path},
    );
  }
}
