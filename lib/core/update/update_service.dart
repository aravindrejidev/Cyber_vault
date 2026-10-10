import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_vault/core/update/app_info.dart';
import 'package:cyber_vault/core/update/update_info.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A problem that can be shown to the user as-is.
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the user cancels a running download.
class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// Looks for new releases on GitHub and downloads them. The only network
/// traffic of the whole app: no vault data is ever sent anywhere.
class UpdateService {
  UpdateService();

  static const String _autoKey = 'cybervault.update.auto';
  static const String _skippedKey = 'cybervault.update.skipped';
  static const Duration _timeout = Duration(seconds: 20);

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  /// False for local builds that were not made by the release workflow.
  bool get isConfigured => AppInfo.githubRepo.isNotEmpty;

  // -------------------------------------------------------------------------
  // Settings
  // -------------------------------------------------------------------------

  Future<bool> isAutoCheckEnabled() async {
    try {
      return (await _storage.read(key: _autoKey)) != 'off';
    } catch (_) {
      return true;
    }
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    try {
      await _storage.write(key: _autoKey, value: enabled ? 'on' : 'off');
    } catch (_) {
      // Not critical.
    }
  }

  /// Version the user chose "Don't remind" for.
  Future<String?> skippedVersion() async {
    try {
      return await _storage.read(key: _skippedKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> skipVersion(String version) async {
    try {
      await _storage.write(key: _skippedKey, value: version);
    } catch (_) {
      // Not critical.
    }
  }

  // -------------------------------------------------------------------------
  // Check
  // -------------------------------------------------------------------------

  /// Returns the newest release when it is newer than the running app, or null
  /// when the app is up to date. Throws [UpdateException] with a readable
  /// message when the check fails.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!isConfigured) {
      throw const UpdateException('Updates are not available in this build.');
    }
    final HttpClient client = HttpClient()..connectionTimeout = _timeout;
    try {
      final Uri uri = Uri.https(
        'api.github.com',
        '/repos/${AppInfo.githubRepo}/releases/latest',
      );
      final HttpClientRequest request =
          await client.getUrl(uri).timeout(_timeout);
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'CyberVault-Updater');
      final HttpClientResponse response =
          await request.close().timeout(_timeout);
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) {
        throw const UpdateException(
          'No release found. The repository must be public and have a published release.',
        );
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const UpdateException(
          'GitHub is limiting requests right now. Try again later.',
        );
      }
      if (response.statusCode != 200) {
        throw UpdateException(
          'GitHub answered with HTTP ${response.statusCode}.',
        );
      }

      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const UpdateException('Unexpected answer from GitHub.');
      }
      final UpdateInfo? latest = UpdateInfo.fromGithubRelease(decoded);
      if (latest == null) {
        throw const UpdateException('The latest release has no APK file.');
      }
      return latest.isNewerThan(AppInfo.version) ? latest : null;
    } on IOException {
      throw const UpdateException(
        'Could not reach GitHub. Check your internet connection.',
      );
    } on TimeoutException {
      throw const UpdateException('GitHub did not answer in time. Try again.');
    } on FormatException {
      throw const UpdateException('Unexpected answer from GitHub.');
    } finally {
      client.close(force: true);
    }
  }

  // -------------------------------------------------------------------------
  // Files
  // -------------------------------------------------------------------------

  /// Folder inside the app cache that the FileProvider is allowed to share.
  static Future<Directory> downloadDir() async {
    final Directory cache = await getTemporaryDirectory();
    final Directory dir = Directory(p.join(cache.path, 'updates'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> emptyDir(Directory dir) async {
    try {
      final List<FileSystemEntity> entries = await dir.list().toList();
      for (final FileSystemEntity entry in entries) {
        if (entry is File) {
          await entry.delete();
        }
      }
    } catch (_) {
      // Best effort only.
    }
  }

  /// Removes APKs left over from earlier downloads.
  Future<void> cleanupDownloads() async {
    try {
      await emptyDir(await downloadDir());
    } catch (_) {
      // Best effort only.
    }
  }

  /// Only HTTPS addresses on GitHub are accepted for downloads.
  static bool isTrustedUrl(Uri uri) {
    if (uri.scheme != 'https') return false;
    final String host = uri.host.toLowerCase();
    return host == 'github.com' ||
        host.endsWith('.github.com') ||
        host == 'githubusercontent.com' ||
        host.endsWith('.githubusercontent.com');
  }
}

/// One cancellable APK download. Android itself refuses to install the file
/// unless it is signed with the same key as the installed app.
class UpdateDownload {
  UpdateDownload(this.info);

  final UpdateInfo info;
  HttpClient? _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  /// Downloads the APK and returns the file. [onProgress] receives the bytes
  /// received so far and the total (0 when unknown), at most ~8 times a second.
  Future<File> run(void Function(int received, int total) onProgress) async {
    final Uri uri = Uri.parse(info.apkUrl);
    if (!UpdateService.isTrustedUrl(uri)) {
      throw const UpdateException(
        'The download address is not a trusted GitHub address.',
      );
    }

    final Directory dir = await UpdateService.downloadDir();
    await UpdateService.emptyDir(dir);
    final File file = File(p.join(dir.path, 'cyber-vault-${info.version}.apk'));

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    _client = client;
    IOSink? sink;
    bool completed = false;
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'CyberVault-Updater');
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        throw UpdateException('Download failed (HTTP ${response.statusCode}).');
      }

      final int total = info.apkSize > 0
          ? info.apkSize
          : (response.contentLength > 0 ? response.contentLength : 0);
      sink = file.openWrite();
      int received = 0;
      final Stopwatch clock = Stopwatch()..start();
      await for (final List<int> chunk in response) {
        if (_cancelled) throw const UpdateCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (clock.elapsedMilliseconds >= 120) {
          clock.reset();
          onProgress(received, total);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      onProgress(received, total);

      if (info.apkSize > 0 && received != info.apkSize) {
        throw const UpdateException(
          'The download was incomplete. Please try again.',
        );
      }
      completed = true;
      return file;
    } on FileSystemException {
      throw const UpdateException(
        'Could not save the update file. Is the storage full?',
      );
    } on IOException {
      if (_cancelled) throw const UpdateCancelled();
      throw const UpdateException('The connection was lost during the download.');
    } finally {
      client.close(force: true);
      _client = null;
      try {
        await sink?.close();
      } catch (_) {
        // Ignore.
      }
      if (!completed) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Ignore.
        }
      }
    }
  }
}
