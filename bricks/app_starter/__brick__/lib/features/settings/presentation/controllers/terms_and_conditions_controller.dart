import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../data/repository/settings_content_repository.dart';

class TermsAndConditionsController extends GetxController {
  TermsAndConditionsController(this._repository);

  final SettingsContentRepository _repository;

  final state = TheStates.loading.obs;
  final html = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    state.value = TheStates.loading;
    final result = await _repository.getTermsHtml();
    result.fold(
      (error) => state.value = TheStates.error,
      (content) {
        html.value = content;
        state.value = TheStates.success;
      },
    );
  }

  Future<void> retry() => _load();

  Future<void> reload() => _load();
}
