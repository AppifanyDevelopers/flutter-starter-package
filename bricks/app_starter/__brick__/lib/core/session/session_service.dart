import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

/// Owns the logged-in flag and token storage. `GetMiddleware.redirect` is
/// synchronous but secure-storage reads are not, so [isLoggedInSync] is an
/// in-memory cache hydrated once at boot (see SplashController) and kept up
/// to date on login/logout -- guards read the cache, never storage directly.
class SessionService {
  SessionService({FlutterSecureStorage? secureStorage, GetStorage? box})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _box = box ?? GetStorage();

  static const _tokenKey = 'access_token';
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const _rememberedEmailKey = 'remembered_email';

  final FlutterSecureStorage _secureStorage;
  final GetStorage _box;

  bool _isLoggedInSync = false;
  bool get isLoggedInSync => _isLoggedInSync;

  Future<void> hydrate() async {
    final token = await _secureStorage.read(key: _tokenKey);
    _isLoggedInSync = token != null && token.isNotEmpty;
  }

  Future<void> saveSession(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    _isLoggedInSync = true;
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _tokenKey);
    _isLoggedInSync = false;
  }

  bool get hasSeenOnboarding => _box.read<bool>(_hasSeenOnboardingKey) ?? false;

  Future<void> setHasSeenOnboarding() => _box.write(_hasSeenOnboardingKey, true);

  /// "Remember me" only remembers the email for next time -- the session
  /// itself already persists across restarts via secure storage regardless
  /// of this flag.
  String? get rememberedEmail => _box.read<String>(_rememberedEmailKey);

  Future<void> setRememberedEmail(String? email) {
    if (email == null || email.isEmpty) return _box.remove(_rememberedEmailKey);
    return _box.write(_rememberedEmailKey, email);
  }
}
