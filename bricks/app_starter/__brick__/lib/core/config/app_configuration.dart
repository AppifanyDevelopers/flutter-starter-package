import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../build_variants/app_environment.dart';

/// The only place in the app allowed to read `dotenv.env[...]` -- every
/// other file reads flavor/environment values through this class.
class AppConfiguration {
  AppConfiguration._({required this.environment});

  static final AppConfiguration staging = AppConfiguration._(environment: AppEnvironment.staging);
  static final AppConfiguration di = AppConfiguration._(environment: AppEnvironment.di);
  static final AppConfiguration production = AppConfiguration._(environment: AppEnvironment.production);

  /// Set once in `main.dart` after `dotenv.load` resolves the active flavor.
  static late AppConfiguration current;

  final AppEnvironment environment;

  bool get isProduction => environment == AppEnvironment.production;

  String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';
}
