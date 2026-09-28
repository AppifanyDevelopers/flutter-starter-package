import 'package:dartz/dartz.dart';

import '../../../../core/errors/app_error.dart';
import '../model/notification_preference.dart';
import 'notification_settings_repository.dart';

class FakeNotificationSettingsRepository implements NotificationSettingsRepository {
  var _preferences = const [
    NotificationPreference(key: 'push', label: 'Push notifications', isEnabled: true),
    NotificationPreference(key: 'email', label: 'Email updates', isEnabled: true),
    NotificationPreference(key: 'sms', label: 'SMS alerts', isEnabled: false),
  ];

  @override
  Future<Either<AppError, List<NotificationPreference>>> getPreferences() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return right(_preferences);
  }

  @override
  Future<Either<AppError, Unit>> updatePreference({required String key, required bool isEnabled}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _preferences = [
      for (final preference in _preferences)
        if (preference.key == key) preference.copyWith(isEnabled: isEnabled) else preference,
    ];
    return right(unit);
  }
}
