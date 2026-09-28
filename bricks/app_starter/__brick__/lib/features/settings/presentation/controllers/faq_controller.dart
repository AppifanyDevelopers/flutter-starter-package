import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../data/model/faq_item.dart';
import '../../data/repository/settings_content_repository.dart';

class FaqController extends GetxController {
  FaqController(this._repository);

  static const _pageSize = 10;

  final SettingsContentRepository _repository;
  final scrollController = ScrollController();

  final state = TheStates.loading.obs;
  final faqs = <FaqItem>[].obs;
  final query = ''.obs;
  final isLoadingMore = false.obs;

  int _page = 1;
  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    _load();
    scrollController.addListener(_onScroll);
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!_hasMore || isLoadingMore.value || state.value != TheStates.success) return;
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  void search(String value) {
    query.value = value;
    _load();
  }

  Future<void> retry() => _load();

  Future<void> reload() => _load();

  Future<void> _load() async {
    state.value = TheStates.loading;
    _page = 1;
    final result = await _repository.getFaqs(page: _page, pageSize: _pageSize, query: query.value);
    result.fold(
      (error) => state.value = TheStates.error,
      (items) {
        faqs.assignAll(items);
        _hasMore = items.length == _pageSize;
        state.value = TheStates.success;
      },
    );
  }

  Future<void> loadMore() async {
    if (!_hasMore || isLoadingMore.value) return;

    isLoadingMore.value = true;
    final nextPage = _page + 1;
    final result = await _repository.getFaqs(page: nextPage, pageSize: _pageSize, query: query.value);
    result.fold(
      (error) {}, // Silently keep what's already loaded; the user can retry by scrolling again.
      (items) {
        faqs.addAll(items);
        _page = nextPage;
        _hasMore = items.length == _pageSize;
      },
    );
    isLoadingMore.value = false;
  }
}
