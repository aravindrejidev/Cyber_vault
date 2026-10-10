/// Values injected at build time by the release workflow
/// (`--dart-define=APP_VERSION=...` and `--dart-define=GITHUB_REPO=owner/repo`).
/// Local builds without these defines have the updater switched off.
class AppInfo {
  AppInfo._();

  /// Version of the running app, e.g. `1.0.3`.
  static const String version =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

  /// `owner/repository` whose GitHub releases are checked for updates.
  static const String githubRepo =
      String.fromEnvironment('GITHUB_REPO', defaultValue: '');
}
