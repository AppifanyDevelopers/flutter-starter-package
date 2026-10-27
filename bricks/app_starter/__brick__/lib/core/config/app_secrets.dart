/// Compile-time secrets, supplied per build and never stored in the repo.
///
/// `.env.*` files are bundled into the app as assets, so anyone can read them
/// out of the APK/IPA: they may only hold non-secret config (the API base URL).
/// A key that must not be extractable still isn't safe in a client app, but it
/// at least must not be committed. Pass it at build time instead:
///
///   flutter run --flavor staging --dart-define-from-file=dart_defines/staging.json
///
/// `dart_defines/<flavor>.json` is git-ignored; copy `<flavor>.json.example`.
/// Add each secret here as a `String.fromEnvironment` const -- the name must be
/// a literal, which is why this is a class and not a lookup by string.
abstract class AppSecrets {
  AppSecrets._();

  /// Example: a third-party SDK key. Rename or replace with your own.
  static const apiKey = String.fromEnvironment('API_KEY');

  /// True when every secret the app needs was provided. Extend as you add more.
  static bool get isConfigured => apiKey.isNotEmpty;
}
