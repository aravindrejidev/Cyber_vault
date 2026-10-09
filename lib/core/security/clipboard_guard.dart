import 'dart:async';

import 'package:flutter/services.dart';

/// Copies secrets to the clipboard and wipes them again after a delay.
class ClipboardGuard {
  ClipboardGuard._();

  static Timer? _timer;
  static String? _lastSecret;

  static Future<void> copySecret(
    String value, {
    Duration clearAfter = const Duration(seconds: 30),
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    _lastSecret = value;
    _timer?.cancel();
    _timer = Timer(clearAfter, () {
      clearNow();
    });
  }

  /// Clears the clipboard if it still holds the secret we copied (or if we can
  /// no longer read it, e.g. while the app is in the background).
  static Future<void> clearNow() async {
    _timer?.cancel();
    _timer = null;
    final String? secret = _lastSecret;
    if (secret == null) return;
    _lastSecret = null;
    try {
      final ClipboardData? current = await Clipboard.getData(Clipboard.kTextPlain);
      final String? text = current?.text;
      if (text == null || text.isEmpty || text == secret) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {
      // Best effort only.
    }
  }
}
