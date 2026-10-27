import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

import '../telemetry/telemetry.dart';

/// Owns the logged-in flag and token storage. `GetMiddleware.redirect` is
/// synchronous but secure-storage reads are not, so [isLoggedInSync] is an
/// in-memory cache hydrated once at boot (see SplashController) and kept up
/// to date on login/logout -- guards read the cache, never storage directly.
class SessionService {
  SessionService({FlutterSecureStorage? secureStorage, GetStorage? box})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _injectedBox = box;

  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const _rememberedEmailKey = 'remembered_email';

  final FlutterSecureStorage _secureStorage;
  final GetStorage? _injectedBox;

  // Created on first use, so a session that never touches preferences (login,
  // logout) doesn't need GetStorage initialised -- which also keeps it testable.
  late final GetStorage _box = _injectedBox ?? GetStorage();

  bool _isLoggedInSync = false;
  bool get isLoggedInSync => _isLoggedInSync;

  Future<void> hydrate() async {
    final token = await _secureStorage.read(key: _tokenKey);
    _isLoggedInSync = token != null && token.isNotEmpty;
    // Restore the crash/analytics identity for a returning user.
    final userId = _isLoggedInSync ? await _secureStorage.read(key: _userIdKey) : null;
    if (userId != null && userId.isNotEmpty) await Telemetry.identify(userId);
  }

  /// Async read of the stored access token, for the `Authorization` header.
  Future<String?> readToken() => _secureStorage.read(key: _tokenKey);

  bool _pushPromptPending = false;

  /// True right after a login/signup, until the dashboard has offered the
  /// push-notification prompt once. Not persisted: restarting the app while
  /// already logged in never re-asks.
  bool consumePushPrompt() {
    final pending = _pushPromptPending;
    _pushPromptPending = false;
    return pending;
  }

  /// Test seam: behaves like a login (marks the session and the pending push
  /// prompt) without touching secure storage.
  @visibleForTesting
  void markLoggedInForTest() {
    _isLoggedInSync = true;
    _pushPromptPending = true;
  }

  /// [userId] is the backend's id for the user: it is stored so crashes and
  /// analytics can be tied to the user, including after an app restart.
  Future<void> saveSession(String token, {String? userId}) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    if (userId != null && userId.isNotEmpty) {
      await _secureStorage.write(key: _userIdKey, value: userId);
      await Telemetry.identify(userId);
    }
    _isLoggedInSync = true;
    _pushPromptPending = true;
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
    await Telemetry.clearUser();
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
