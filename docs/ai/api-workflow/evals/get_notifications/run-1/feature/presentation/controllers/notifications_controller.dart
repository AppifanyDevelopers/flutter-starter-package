import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/model/notification_item.dart';
import '../../data/repository/notifications_repository.dart';

class NotificationsController extends GetxController {
  NotificationsController(this._repository);

  final NotificationsRepository _repository;
  final scrollController = ScrollController();

  final state = TheStates.loading.obs;
  final errorMessage = ''.obs;
  final notifications = <NotificationItem>[].obs;
  final isLoadingMore = false.obs;
  final loadMoreFailed = false.obs;

  int _page = 1;
  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    reload();
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!_hasMore ||
        isLoadingMore.value ||
        loadMoreFailed.value ||
        !state.value.isSuccess) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  Future<void> reload() async {
    state.value = TheStates.loading;
    loadMoreFailed.value = false;
    _page = 1;
    final result = await _repository.getNotifications(page: _page);
    result.fold(
      (error) {
        errorMessage.value = error.message;
        state.value = TheStates.error;
      },
      (page) {
        notifications.assignAll(page.items);
        _hasMore = page.meta.hasMore;
        state.value = TheStates.success;
      },
    );
  }

  /// Pull-to-refresh: keeps the list on screen (no shimmer) so the refresh
  /// indicator survives, and keeps the old list if the request fails.
  Future<void> pullToRefresh() async {
    final result = await _repository.getNotifications(page: 1);
    result.fold(
      (error) => Get.snackbar('Could not refresh', error.message),
      (page) {
        _page = 1;
        loadMoreFailed.value = false;
        notifications.assignAll(page.items);
        _hasMore = page.meta.hasMore;
        state.value = TheStates.success;
      },
    );
  }

  Future<void> loadMore() async {
    if (!_hasMore || isLoadingMore.value) return;

    isLoadingMore.value = true;
    loadMoreFailed.value = false;
    final nextPage = _page + 1;
    final result = await _repository.getNotifications(page: nextPage);
    result.fold(
      // Keep what is already loaded; the inline retry row calls loadMore again.
      (error) => loadMoreFailed.value = true,
      (page) {
        notifications.addAll(page.items);
        _page = nextPage;
        _hasMore = page.meta.hasMore;
      },
    );
    isLoadingMore.value = false;
  }

  /// Tapping a notification without a `url` marks it read. Behaviour for a
  /// notification that has a `url` is not decided yet, so nothing happens.
  Future<void> onTap(NotificationItem item) async {
    if (item.url != null || item.isRead) return;

    final index = notifications.indexWhere((n) => n.id == item.id);
    if (index == -1) return;

    // Optimistic: mark read now, revert if the call fails.
    notifications[index] =
        item.copyWith(readAt: DateTime.now().toUtc().toIso8601String());
    final result = await _repository.markAsRead(item.id);
    result.fold(
      (error) {
        final current = notifications.indexWhere((n) => n.id == item.id);
        if (current == -1) return;
        if (error is ApiErrorResponse && error.statusCode == 404) {
          notifications.removeAt(current);
        } else {
          notifications[current] = item.copyWith(clearReadAt: true);
        }
        Get.snackbar('Could not mark as read', error.message);
      },
      (_) {},
    );
  }
}
