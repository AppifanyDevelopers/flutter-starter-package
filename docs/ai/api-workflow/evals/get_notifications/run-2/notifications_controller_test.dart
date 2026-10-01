import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:verify_app/core/enums/the_states.dart';
import 'package:verify_app/core/errors/app_error.dart';
import 'package:verify_app/features/notifications/data/model/app_notification.dart';
import 'package:verify_app/features/notifications/data/repository/notifications_repository.dart';
import 'package:verify_app/features/notifications/presentation/controllers/notifications_controller.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  final Map<int, Either<AppError, NotificationsPage>> pages = {};
  Either<AppError, Unit> markResult = right(unit);
  final markedIds = <int>[];

  @override
  Future<Either<AppError, NotificationsPage>> getNotifications({required int page}) async =>
      pages[page] ?? left(const InternalAppError(message: 'no page'));

  @override
  Future<Either<AppError, Unit>> markAsRead(int id) async {
    markedIds.add(id);
    return markResult;
  }
}

AppNotification n(int id, {String? readAt, String? url}) =>
    AppNotification(id: id, title: 't$id', body: 'b$id', readAt: readAt, url: url);

void main() {
  late FakeNotificationsRepository repo;
  late NotificationsController controller;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
  }

  setUp(() {
    repo = FakeNotificationsRepository();
  });

  test('model parses title/body, nullable read_at and url', () {
    final item = AppNotification.fromJson({
      'id': 91,
      'data': {'title': 'T', 'body': 'B', 'data': []},
      'read_at': null,
      'url': null,
    });
    expect(item.title, 'T');
    expect(item.body, 'B');
    expect(item.isRead, isFalse);
    expect(item.url, isNull);
  });

  test('load success populates list', () async {
    repo.pages[1] = right(NotificationsPage(items: [n(1), n(2)], hasMore: false));
    controller = NotificationsController(repo);
    await controller.load();
    expect(controller.state.value, TheStates.success);
    expect(controller.notifications.length, 2);
  });

  test('load failure sets error state with message', () async {
    repo.pages[1] = left(const ApiErrorResponse(message: 'boom', statusCode: 500, code: 'server_error'));
    controller = NotificationsController(repo);
    await controller.load();
    expect(controller.state.value, TheStates.error);
    expect(controller.errorMessage.value, 'boom');
  });

  test('empty list is success with no items', () async {
    repo.pages[1] = right(const NotificationsPage(items: [], hasMore: false));
    controller = NotificationsController(repo);
    await controller.load();
    expect(controller.state.value, TheStates.success);
    expect(controller.notifications, isEmpty);
  });

  test('loadMore appends next page, failure keeps list and flags retry', () async {
    repo.pages[1] = right(NotificationsPage(items: [n(1)], hasMore: true));
    repo.pages[2] = left(const ConnectionError());
    controller = NotificationsController(repo);
    await controller.load();

    await controller.loadMore();
    expect(controller.notifications.length, 1);
    expect(controller.loadMoreFailed.value, isTrue);
    expect(controller.state.value, TheStates.success);

    repo.pages[2] = right(NotificationsPage(items: [n(2)], hasMore: false));
    await controller.retryLoadMore();
    expect(controller.notifications.map((e) => e.id), [1, 2]);
    expect(controller.loadMoreFailed.value, isFalse);

    await controller.loadMore(); // no more pages: no-op
    expect(controller.notifications.length, 2);
  });

  testWidgets('refresh keeps list on failure and never shows loading', (tester) async {
    await pumpApp(tester);
    repo.pages[1] = right(NotificationsPage(items: [n(1)], hasMore: false));
    controller = NotificationsController(repo);
    await controller.load();

    repo.pages[1] = left(const ConnectionError());
    final future = controller.refreshList();
    expect(controller.state.value, TheStates.success);
    await future;
    expect(controller.notifications.length, 1);
    expect(controller.state.value, TheStates.success);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  test('onTap with url set does not mark as read', () async {
    repo.pages[1] = right(NotificationsPage(items: [n(1, url: 'https://x')], hasMore: false));
    controller = NotificationsController(repo);
    await controller.load();
    await controller.onTap(controller.notifications.first);
    expect(repo.markedIds, isEmpty);
    expect(controller.notifications.first.isRead, isFalse);
  });

  test('onTap on unread, url-less item marks it read in place', () async {
    repo.pages[1] = right(NotificationsPage(items: [n(1), n(2)], hasMore: false));
    controller = NotificationsController(repo);
    await controller.load();
    await controller.onTap(controller.notifications.first);
    expect(repo.markedIds, [1]);
    expect(controller.notifications.first.isRead, isTrue);
    expect(controller.notifications.last.isRead, isFalse);
  });

  test('onTap on an already read item does nothing', () async {
    repo.pages[1] = right(NotificationsPage(items: [n(1, readAt: 'x')], hasMore: false));
    controller = NotificationsController(repo);
    await controller.load();
    await controller.onTap(controller.notifications.first);
    expect(repo.markedIds, isEmpty);
  });

  testWidgets('mark-read failure reverts and shows snackbar', (tester) async {
    await pumpApp(tester);
    repo.pages[1] = right(NotificationsPage(items: [n(1)], hasMore: false));
    repo.markResult = left(const ApiErrorResponse(message: 'nope', statusCode: 403, code: 'forbidden'));
    controller = NotificationsController(repo);
    await controller.load();
    await controller.onTap(controller.notifications.first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.notifications.first.isRead, isFalse);
    expect(find.text('nope'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('mark-read 404 removes the item', (tester) async {
    await pumpApp(tester);
    repo.pages[1] = right(NotificationsPage(items: [n(1), n(2)], hasMore: false));
    repo.markResult = left(const ApiErrorResponse(message: 'gone', statusCode: 404, code: 'not_found'));
    controller = NotificationsController(repo);
    await controller.load();
    await controller.onTap(controller.notifications.first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.notifications.map((e) => e.id), [2]);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
