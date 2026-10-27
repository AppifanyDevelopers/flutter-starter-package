enum AppEnvironment { staging, di, production }

extension AppEnvironmentX on AppEnvironment {
  /// Label drawn on the in-app corner banner and on the launcher icon.
  /// Null for production, which shows neither.
  String? get bannerLabel => switch (this) {
        AppEnvironment.staging => 'STAGING',
        AppEnvironment.di => 'DI',
        AppEnvironment.production => null,
      };
}
