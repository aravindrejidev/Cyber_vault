import 'package:file_picker/file_picker.dart';

/// The file picker copies chosen files into the app cache (unencrypted).
/// We clear that cache as soon as we are done with it, on lock and on start.
class TempCleaner {
  TempCleaner._();

  static Future<void> clear() async {
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {
      // Best effort only.
    }
  }
}
