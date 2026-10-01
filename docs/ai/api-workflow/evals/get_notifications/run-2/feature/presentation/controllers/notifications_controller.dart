import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/model/app_notification.dart';
import '../../data/repository/notifications_repository.dart';

class NotificationsController extends GetxController {
  NotificationsController(this._repository);

  final NotificationsRepository _repository;
  final scrollController = ScrollController();

  final state = TheStates.loading.obs;
  final notifications = <AppNotification>[].obs;
  final isLoadingMore = false.obs;
  final loadMoreFailed = false.obs;
  final errorMessage = ''.obs;

  int _page = 1;
  bool _hasMore = false;
  bool _isRefreshing = false;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    load();
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  /// Initial load (and retry from the error view): shows the shimmer.
  Future<void> load() async {
    state.value = TheStates.loading;
    _page = 1;
    final result = await _repository.getNotifications(page: 1);
    result.fold(
      (error) {
        errorMessage.value = error.message;
        state.value = TheStates.error;
      },
      (page) {
        notifications.assignAll(page.items);
        _hasMore = page.hasMore;
        loadMoreFailed.value = false;
        state.value = TheStates.success;
      },
    );
  }

  /// Pull-to-refresh (named refreshList; GetxController already has refresh()): keeps the current list visible and on failure.
  Future<void> refreshList() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final result = await _repository.getNotifications(page: 1);
    result.fold(
      (error) => _showError(error.message),
      (page) {
        notifications.assignAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
        loadMoreFailed.value = false;
        state.value = TheStates.success;
      },
    );
    _isRefreshing = false;
  }

  Future<void> loadMore() async {
    if (!_hasMore || isLoadingMore.value || loadMoreFailed.value || state.value != TheStates.success) return;

    isLoadingMore.value = true;
    final nextPage = _page + 1;
    final result = await _repository.getNotifications(page: nextPage);
    result.fold(
      (error) => loadMoreFailed.value = true,
      (page) {
        notifications.addAll(page.items);
        _page = nextPage;
        _hasMore = page.hasMore;
      },
    );
    isLoadingMore.value = false;
  }

  Future<void> retryLoadMore() {
    loadMoreFailed.value = false;
    return loadMore();
  }

  /// Tapping marks as read only when there is no url; navigating to a url is
  /// not implemented.
  Future<void> onTap(AppNotification item) async {
    if (item.url != null || item.isRead) return;
    await markAsRead(item);
  }

  Future<void> markAsRead(AppNotification item) async {
    final index = notifications.indexWhere((n) => n.id == item.id);
    if (index < 0) return;

    notifications[index] = item.copyWith(readAt: DateTime.now().toUtc().toIso8601String());
    final result = await _repository.markAsRead(item.id);
    result.fold(
      (error) {
        final current = notifications.indexWhere((n) => n.id == item.id);
        if (error is ApiErrorResponse && error.code == 'not_found') {
          if (current >= 0) notifications.removeAt(current);
        } else if (current >= 0) {
          notifications[current] = item;
        }
        _showError(error.message);
      },
      (_) {},
    );
  }

  void _showError(String message) {
    Get.snackbar('Notifications', message);
  }
}
