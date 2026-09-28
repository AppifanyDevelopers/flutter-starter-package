import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../data/model/notification_preference.dart';
import '../../data/repository/notification_settings_repository.dart';

class NotificationSettingsController extends GetxController {
  NotificationSettingsController(this._repository);

  final NotificationSettingsRepository _repository;

  final state = TheStates.loading.obs;
  final preferences = <NotificationPreference>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    state.value = TheStates.loading;
    final result = await _repository.getPreferences();
    result.fold(
      (error) => state.value = TheStates.error,
      (items) {
        preferences.assignAll(items);
        state.value = TheStates.success;
      },
    );
  }

  void retry() => _load();

  Future<void> toggle(NotificationPreference preference, bool isEnabled) async {
    final index = preferences.indexWhere((p) => p.key == preference.key);
    if (index == -1) return;

    preferences[index] = preference.copyWith(isEnabled: isEnabled);
    final result = await _repository.updatePreference(key: preference.key, isEnabled: isEnabled);
    result.fold(
      (error) {
        // Revert on failure.
        preferences[index] = preference;
        Get.snackbar('Could not update', error.message);
      },
      (_) {},
    );
  }
}
