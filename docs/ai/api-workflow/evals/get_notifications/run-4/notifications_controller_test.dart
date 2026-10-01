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
  final pages = <int, Either<AppError, NotificationsPage>>{};
  Either<AppError, Unit> markResult = right(unit);
  final requestedPages = <int>[];
  final markedIds = <int>[];

  @override
  Future<Either<AppError, NotificationsPage>> getNotifications({required int page}) async {
    requestedPages.add(page);
    return pages[page] ?? right(const NotificationsPage(items: [], hasMore: false));
  }

  @override
  Future<Either<AppError, Unit>> markRead(int id) async {
    markedIds.add(id);
    return markResult;
  }
}

AppNotification n(int id, {bool read = false}) => AppNotification(
      id: id,
      title: 'T$id',
      body: 'B$id',
      readAt: read ? DateTime(2026) : null,
    );

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
}

void main() {
  late FakeNotificationsRepository repo;
  late NotificationsController controller;

  setUp(() {
    Get.reset();
    repo = FakeNotificationsRepository();
    controller = NotificationsController(repo);
  });

  tearDown(Get.reset);

  test('AppNotification.fromJson models title/body/read_at only', () {
    final item = AppNotification.fromJson({
      'id': 91,
      'url': 'https://x',
      'read_at': null,
      'data': {'title': 'Hi', 'body': 'There', 'data': []},
    });
    expect(item.id, 91);
    expect(item.title, 'Hi');
    expect(item.body, 'There');
    expect(item.isRead, isFalse);

    final read = AppNotification.fromJson({
      'id': 1,
      'read_at': '2026-09-30T09:56:45.000000Z',
      'data': {'title': 'a', 'body': 'b'},
    });
    expect(read.isRead, isTrue);
  });

  testWidgets('load success fills the list and derives hasMore from meta', (tester) async {
    repo.pages[1] = right(NotificationsPage(items: [n(1), n(2)], hasMore: true));
    repo.pages[2] = right(NotificationsPage(items: [n(3)], hasMore: false));
    await controller.load();
    expect(controller.state.value, TheStates.success);
    expect(controller.notifications.length, 2);

    await controller.loadMore();
    expect(controller.notifications.map((e) => e.id), [1, 2, 3]);

    await controller.loadMore();
    expect(repo.requestedPages, [1, 2]);
  });

  testWidgets('empty first page is success with an empty list', (tester) async {
    await controller.load();
    expect(controller.state.value, TheStates.success);
    expect(controller.notifications, isEmpty);
  });

  testWidgets('load failure sets error state', (tester) async {
    repo.pages[1] = left(const ConnectionError());
    await controller.load();
    expect(controller.state.value, TheStates.error);
  });

  testWidgets('load-more failure keeps the list and can be retried', (tester) async {
    repo.pages[1] = right(NotificationsPage(items: [n(1)], hasMore: true));
    repo.pages[2] = left(const ConnectionError());
    await controller.load();
    await controller.loadMore();
    expect(controller.state.value, TheStates.success);
    expect(controller.notifications.length, 1);
    expect(controller.loadMoreFailed.value, isTrue);

    repo.pages[2] = right(NotificationsPage(items: [n(2)], hasMore: false));
    await controller.retryLoadMore();
    expect(controller.loadMoreFailed.value, isFalse);
    expect(controller.notifications.length, 2);
  });

  testWidgets('pull-to-refresh failure keeps list, never loading, shows snackbar', (tester) async {
    await pumpApp(tester);
    repo.pages[1] = right(NotificationsPage(items: [n(1)], hasMore: false));
    await controller.load();

    repo.pages[1] = left(const ConnectionError());
    final states = <TheStates>[];
    final worker = ever(controller.state, states.add);
    await controller.pullToRefresh();
    worker.dispose();
    await tester.pump();

    expect(states, isEmpty);
    expect(controller.state.value, TheStates.success);
    expect(controller.notifications.length, 1);
    expect(find.text('Could not refresh'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('pull-to-refresh success replaces the list', (tester) async {
    repo.pages[1] = right(NotificationsPage(items: [n(1)], hasMore: false));
    await controller.load();
    repo.pages[1] = right(NotificationsPage(items: [n(5), n(6)], hasMore: false));
    await controller.pullToRefresh();
    expect(controller.notifications.map((e) => e.id), [5, 6]);
  });

  testWidgets('tapping an unread tile marks it read', (tester) async {
    repo.pages[1] = right(NotificationsPage(items: [n(1)], hasMore: false));
    await controller.load();
    await controller.onTapNotification(controller.notifications.first);
    expect(repo.markedIds, [1]);
    expect(controller.notifications.first.isRead, isTrue);
  });

  testWidgets('tapping a read tile does nothing', (tester) async {
    repo.pages[1] = right(NotificationsPage(items: [n(1, read: true)], hasMore: false));
    await controller.load();
    await controller.onTapNotification(controller.notifications.first);
    expect(repo.markedIds, isEmpty);
  });

  testWidgets('mark-read failure reverts and shows snackbar', (tester) async {
    await pumpApp(tester);
    repo.pages[1] = right(NotificationsPage(items: [n(1)], hasMore: false));
    await controller.load();
    repo.markResult = left(const ApiErrorResponse(message: 'Nope', statusCode: 403, code: 'forbidden'));
    await controller.onTapNotification(controller.notifications.first);
    await tester.pump();

    expect(controller.notifications.first.isRead, isFalse);
    expect(find.text('Could not mark as read'), findsOneWidget);
    expect(find.text('Nope'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('mark-read 404 removes the item and shows snackbar', (tester) async {
    await pumpApp(tester);
    repo.pages[1] = right(NotificationsPage(items: [n(1), n(2)], hasMore: false));
    await controller.load();
    repo.markResult = left(const ApiErrorResponse(message: 'Gone', statusCode: 404, code: 'not_found'));
    await controller.onTapNotification(controller.notifications.first);
    await tester.pump();

    expect(controller.notifications.map((e) => e.id), [2]);
    expect(find.text('Could not mark as read'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
