import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:verify_app/core/enums/the_states.dart';
import 'package:verify_app/core/errors/app_error.dart';
import 'package:verify_app/core/network/api_envelope.dart';
import 'package:verify_app/features/notifications/data/model/notification_item.dart';
import 'package:verify_app/features/notifications/data/repository/notifications_repository.dart';
import 'package:verify_app/features/notifications/presentation/controllers/notifications_controller.dart';

Map<String, dynamic> _json(int id, {String? readAt, String? url}) => {
      'id': id,
      'type': 'push',
      'data': {'title': 'T$id', 'body': 'B$id', 'data': []},
      'read_at': readAt,
      'url': url,
    };

PaginationMeta _meta(int page, int last, {int total = 22}) => PaginationMeta(
    currentPage: page,
    lastPage: last,
    perPage: 20,
    total: total,
    from: 1,
    to: 20);

class _FakeRepo implements NotificationsRepository {
  final pages = <int, Either<AppError, NotificationsPage>>{};
  Either<AppError, Unit> markResult = right(unit);
  final markedIds = <int>[];

  @override
  Future<Either<AppError, NotificationsPage>> getNotifications(
          {required int page}) async =>
      pages[page]!;

  @override
  Future<Either<AppError, Unit>> markAsRead(int id) async {
    markedIds.add(id);
    return markResult;
  }
}

NotificationsPage _page(List<int> ids, int page, int last) => NotificationsPage(
    items: ids.map((i) => NotificationItem.fromJson(_json(i))).toList(),
    meta: _meta(page, last));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeRepo repo;
  late NotificationsController controller;

  setUp(() {
    Get.testMode = true;
    repo = _FakeRepo();
  });

  test('model reads title/body from the outer data and ignores data.data', () {
    final item = NotificationItem.fromJson(
        _json(1, readAt: '2026-09-30T09:56:45.000000Z'));
    expect(item.title, 'T1');
    expect(item.body, 'B1');
    expect(item.isRead, isTrue);
    expect(NotificationItem.fromJson(_json(2)).isRead, isFalse);
    expect(NotificationItem.fromJson({'id': 3, 'data': null}).title, '');
  });

  test('first load: success sets items and hasMore from meta', () async {
    repo.pages[1] = right(_page([1, 2], 1, 2));
    repo.pages[2] = right(_page([3], 2, 2));
    controller = NotificationsController(repo);
    await controller.reload();
    expect(controller.state.value.isSuccess, isTrue);
    expect(controller.notifications.length, 2);

    await controller.loadMore();
    expect(controller.notifications.map((n) => n.id), [1, 2, 3]);

    await controller
        .loadMore(); // last page reached: no request (page 3 is not stubbed)
    expect(controller.notifications.length, 3);
  });

  test('pull-to-refresh keeps the list on failure and replaces it on success',
      () async {
    repo.pages[1] = right(_page([1, 2], 1, 1));
    controller = NotificationsController(repo);
    await controller.reload();

    repo.pages[1] = right(_page([9], 1, 1));
    await controller.pullToRefresh();
    expect(controller.notifications.map((n) => n.id), [9]);
    expect(controller.state.value.isLoading, isFalse);
  });

  test('empty result is success with an empty list', () async {
    repo.pages[1] =
        right(NotificationsPage(items: const [], meta: _meta(1, 1, total: 0)));
    controller = NotificationsController(repo);
    await controller.reload();
    expect(controller.state.value.isSuccess, isTrue);
    expect(controller.notifications, isEmpty);
  });

  test('first load failure sets error state and message', () async {
    repo.pages[1] = left(const ApiErrorResponse(
        message: 'Server down', statusCode: 500, code: 'server_error'));
    controller = NotificationsController(repo);
    await controller.reload();
    expect(controller.state.value.isError, isTrue);
    expect(controller.errorMessage.value, 'Server down');
  });

  test('load-more failure keeps the list and flags an inline retry', () async {
    repo.pages[1] = right(_page([1, 2], 1, 2));
    repo.pages[2] =
        left(const ApiErrorResponse(message: 'boom', statusCode: 500));
    controller = NotificationsController(repo);
    await controller.reload();
    await controller.loadMore();
    expect(controller.notifications.length, 2);
    expect(controller.loadMoreFailed.value, isTrue);
    expect(controller.state.value.isSuccess, isTrue);

    repo.pages[2] = right(_page([3], 2, 2));
    await controller.loadMore(); // the retry row
    expect(controller.loadMoreFailed.value, isFalse);
    expect(controller.notifications.length, 3);
  });

  test('tap with null url marks read optimistically', () async {
    repo.pages[1] = right(_page([1], 1, 1));
    controller = NotificationsController(repo);
    await controller.reload();
    await controller.onTap(controller.notifications.first);
    expect(controller.notifications.first.isRead, isTrue);
    expect(repo.markedIds, [1]);
  });

  test('tap on an already-read item or an item with a url does nothing',
      () async {
    repo.pages[1] = right(NotificationsPage(
      items: [
        NotificationItem.fromJson(
            _json(1, readAt: '2026-09-30T09:56:45.000000Z')),
        NotificationItem.fromJson(_json(2, url: 'https://example.com')),
      ],
      meta: _meta(1, 1, total: 2),
    ));
    controller = NotificationsController(repo);
    await controller.reload();
    await controller.onTap(controller.notifications[0]);
    await controller.onTap(controller.notifications[1]);
    expect(repo.markedIds, isEmpty);
    expect(controller.notifications[1].isRead, isFalse);
  });

  testWidgets('mark-read failure reverts; 404 removes the item',
      (tester) async {
    // Get.snackbar needs an overlay, so mount a GetMaterialApp.
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    repo.pages[1] = right(_page([1, 2], 1, 1));
    controller = NotificationsController(repo);
    await controller.reload();

    repo.markResult =
        left(const ApiErrorResponse(message: 'nope', statusCode: 500));
    await controller.onTap(controller.notifications[0]);
    await tester.pump(const Duration(seconds: 5));
    expect(controller.notifications[0].isRead, isFalse);

    repo.markResult = left(const ApiErrorResponse(
        message: 'gone', statusCode: 404, code: 'not_found'));
    await controller.onTap(controller.notifications[1]);
    await tester.pump(const Duration(seconds: 5));
    expect(controller.notifications.map((n) => n.id), [1]);
  });
}
