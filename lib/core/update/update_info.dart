/// Parses "1.2.3", "v1.2.3" or "1.2.3-beta+4" into [1, 2, 3]. Null if invalid.
List<int>? parseVersion(String input) {
  String text = input.trim();
  if (text.startsWith('v') || text.startsWith('V')) {
    text = text.substring(1);
  }
  final int cut = text.indexOf(RegExp(r'[-+]'));
  if (cut >= 0) {
    text = text.substring(0, cut);
  }
  final List<String> parts = text.split('.');
  if (parts.isEmpty || parts.length > 4) return null;
  final List<int> numbers = <int>[];
  for (final String part in parts) {
    final int? value = int.tryParse(part);
    if (value == null || value < 0) return null;
    numbers.add(value);
  }
  return numbers;
}

/// Negative if [a] < [b], zero if equal, positive if [a] > [b].
int compareVersions(List<int> a, List<int> b) {
  final int length = a.length > b.length ? a.length : b.length;
  for (int i = 0; i < length; i++) {
    final int x = i < a.length ? a[i] : 0;
    final int y = i < b.length ? b[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

/// A published release that contains an installable APK.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.apkName,
    required this.apkSize,
  });

  /// Version without the leading "v".
  final String version;

  /// Release notes shown under "What's new".
  final String notes;
  final String apkUrl;
  final String apkName;

  /// Size in bytes (0 when unknown).
  final int apkSize;

  /// Builds an [UpdateInfo] from the JSON of `GET /repos/{repo}/releases/latest`.
  /// Returns null when the release has no valid version tag or no APK asset.
  static UpdateInfo? fromGithubRelease(Map<String, dynamic> json) {
    final String tag = (json['tag_name'] as String?) ?? '';
    final List<int>? parsed = parseVersion(tag);
    if (parsed == null) return null;
    final String version = parsed.join('.');

    final Object? rawAssets = json['assets'];
    if (rawAssets is! List<dynamic>) return null;
    for (final dynamic asset in rawAssets) {
      if (asset is! Map<String, dynamic>) continue;
      final String name = (asset['name'] as String?) ?? '';
      final String? url = asset['browser_download_url'] as String?;
      if (url == null || !name.toLowerCase().endsWith('.apk')) continue;
      return UpdateInfo(
        version: version,
        notes: ((json['body'] as String?) ?? '').replaceAll('\r\n', '\n').trim(),
        apkUrl: url,
        apkName: name,
        apkSize: (asset['size'] as num?)?.toInt() ?? 0,
      );
    }
    return null;
  }

  bool isNewerThan(String currentVersion) {
    final List<int> latest = parseVersion(version) ?? const <int>[0];
    final List<int> current = parseVersion(currentVersion) ?? const <int>[0];
    return compareVersions(latest, current) > 0;
  }
}
