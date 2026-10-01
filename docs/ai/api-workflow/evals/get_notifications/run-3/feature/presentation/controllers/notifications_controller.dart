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
  final notifications = <NotificationItem>[].obs;
  final isLoadingMore = false.obs;
  final loadMoreFailed = false.obs;

  int _page = 1;
  bool _hasMore = false;
  bool _isRefreshing = false;
  int _generation = 0;
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
    if (!scrollController.hasClients || loadMoreFailed.value) return;
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  /// First load (and the error-state retry): shows the shimmer.
  Future<void> load() async {
    final generation = ++_generation;
    state.value = TheStates.loading;
    loadMoreFailed.value = false;
    isLoadingMore.value = false;
    final result = await _repository.getNotifications(page: 1);
    if (generation != _generation) return;
    result.fold(
      (error) => state.value = TheStates.error,
      (page) {
        notifications.assignAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
        state.value = TheStates.success;
      },
    );
  }

  /// Pull-to-refresh: never leaves the success state and keeps the old list
  /// on failure. (Not named `refresh`: GetxController already has that.)
  Future<void> reload() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final generation = ++_generation;
    isLoadingMore.value = false;
    final result = await _repository.getNotifications(page: 1);
    _isRefreshing = false;
    if (generation != _generation) return;
    result.fold(
      (error) => Get.snackbar('Could not refresh', error.message),
      (page) {
        notifications.assignAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
        loadMoreFailed.value = false;
      },
    );
  }

  Future<void> loadMore() async {
    if (!_hasMore || isLoadingMore.value || _isRefreshing || !state.value.isSuccess) return;

    final generation = _generation;
    isLoadingMore.value = true;
    loadMoreFailed.value = false;
    final nextPage = _page + 1;
    final result = await _repository.getNotifications(page: nextPage);
    if (generation != _generation) return;
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

  Future<void> retryLoadMore() => loadMore();

  /// Tap on a tile. Only unread items without a `url` are marked read;
  /// navigating to a `url` is not decided yet, so those taps do nothing.
  Future<void> onTap(NotificationItem item) async {
    if (item.isRead || item.url != null || _marking.contains(item.id)) return;
    final index = notifications.indexWhere((n) => n.id == item.id);
    if (index == -1) return;

    _marking.add(item.id);
    notifications[index] = item.asRead(DateTime.now());

    final result = await _repository.markRead(item.id);
    _marking.remove(item.id);
    result.fold(
      (error) {
        final current = notifications.indexWhere((n) => n.id == item.id);
        if (error is ApiErrorResponse && error.code == 'not_found') {
          if (current != -1) notifications.removeAt(current);
        } else if (current != -1) {
          notifications[current] = item;
        }
        Get.snackbar('Could not mark as read', error.message);
      },
      (_) {},
    );
  }
}
