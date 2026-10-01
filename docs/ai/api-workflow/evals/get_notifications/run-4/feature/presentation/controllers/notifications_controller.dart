import 'package:flutter/widgets.dart';
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

  int _page = 1;
  bool _hasMore = true;
  bool _isRefreshing = false;
  final _marking = <int>{};

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
    if (position.pixels >= position.maxScrollExtent - 200) loadMore();
  }

  /// Initial load (and the error view's retry). Shows the loading state.
  Future<void> load() async {
    state.value = TheStates.loading;
    final result = await _repository.getNotifications(page: 1);
    result.fold(
      (error) => state.value = TheStates.error,
      (page) {
        notifications.assignAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
        loadMoreFailed.value = false;
        state.value = TheStates.success;
      },
    );
  }

  /// Pull-to-refresh. Never touches [state]; keeps the list on failure.
  Future<void> pullToRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final result = await _repository.getNotifications(page: 1);
    result.fold(
      (error) => Get.snackbar('Could not refresh', error.message),
      (page) {
        notifications.assignAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
        loadMoreFailed.value = false;
      },
    );
    _isRefreshing = false;
  }

  Future<void> loadMore() async {
    if (!_hasMore || isLoadingMore.value || _isRefreshing || loadMoreFailed.value) return;
    if (state.value != TheStates.success) return;

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

  /// Inline retry row after a failed load-more.
  Future<void> retryLoadMore() {
    loadMoreFailed.value = false;
    return loadMore();
  }

  /// Tapping an unread tile marks it read; a read tile does nothing.
  Future<void> onTapNotification(AppNotification notification) async {
    if (notification.isRead || _marking.contains(notification.id)) return;
    _marking.add(notification.id);

    _replace(notification.id, (n) => n.markedRead(DateTime.now()));
    final result = await _repository.markRead(notification.id);
    result.fold(
      (error) {
        final notFound = error is ApiErrorResponse && error.code == 'not_found';
        if (notFound) {
          notifications.removeWhere((n) => n.id == notification.id);
        } else {
          _replace(notification.id, (n) => n.markedUnread());
        }
        Get.snackbar('Could not mark as read', error.message);
      },
      (_) {},
    );
    _marking.remove(notification.id);
  }

  void _replace(int id, AppNotification Function(AppNotification) update) {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    notifications[index] = update(notifications[index]);
  }
}
