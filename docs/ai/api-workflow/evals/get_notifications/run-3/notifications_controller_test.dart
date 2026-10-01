import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:verify_app/core/enums/the_states.dart';
import 'package:verify_app/core/errors/app_error.dart';
import 'package:verify_app/features/notifications/data/model/notification_item.dart';
import 'package:verify_app/features/notifications/data/repository/notifications_repository.dart';
import 'package:verify_app/features/notifications/presentation/controllers/notifications_controller.dart';

NotificationItem item(int id, {DateTime? readAt, String? url}) =>
    NotificationItem(id: id, title: 'Title $id', body: 'Body $id', readAt: readAt, url: url);

class FakeNotificationsRepository implements NotificationsRepository {
  final pages = <int, Either<AppError, NotificationPage>>{};
  Either<AppError, Unit> markResult = right(unit);
  final requestedPages = <int>[];
  final markedIds = <int>[];

  @override
  Future<Either<AppError, NotificationPage>> getNotifications({required int page}) async {
    requestedPages.add(page);
    return pages[page] ?? right(const NotificationPage(items: [], hasMore: false));
  }

  @override
  Future<Either<AppError, Unit>> markRead(int id) async {
    markedIds.add(id);
    return markResult;
  }
}

void main() {
  late FakeNotificationsRepository repo;

  setUp(() {
    repo = FakeNotificationsRepository();
    Get.testMode = true;
  });

  tearDown(Get.reset);

  Future<NotificationsController> pump(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    final c = Get.put(NotificationsController(repo));
    await tester.pump();
    return c;
  }

  testWidgets('loads first page into success state', (tester) async {
    repo.pages[1] = right(NotificationPage(items: [item(1), item(2)], hasMore: true));
    final c = await pump(tester);

    expect(c.state.value, TheStates.success);
    expect(c.notifications.length, 2);
  });

  testWidgets('first load failure yields error state, retry recovers', (tester) async {
    repo.pages[1] = left(const InternalAppError(message: 'boom'));
    final c = await pump(tester);
    expect(c.state.value, TheStates.error);

    repo.pages[1] = right(NotificationPage(items: [item(1)], hasMore: false));
    await c.load();
    expect(c.state.value, TheStates.success);
    expect(c.notifications.length, 1);
  });

  testWidgets('empty list is success with no items', (tester) async {
    repo.pages[1] = right(const NotificationPage(items: [], hasMore: false));
    final c = await pump(tester);
    expect(c.state.value, TheStates.success);
    expect(c.notifications, isEmpty);
  });

  testWidgets('loadMore appends and stops when meta says no more pages', (tester) async {
    repo.pages[1] = right(NotificationPage(items: [item(1)], hasMore: true));
    repo.pages[2] = right(NotificationPage(items: [item(2)], hasMore: false));
    final c = await pump(tester);

    await c.loadMore();
    expect(c.notifications.map((n) => n.id), [1, 2]);

    await c.loadMore();
    expect(repo.requestedPages, [1, 2]);
  });

  testWidgets('loadMore failure keeps list, flags retry, retry succeeds', (tester) async {
    repo.pages[1] = right(NotificationPage(items: [item(1)], hasMore: true));
    repo.pages[2] = left(const ConnectionError());
    final c = await pump(tester);

    await c.loadMore();
    expect(c.notifications.length, 1);
    expect(c.loadMoreFailed.value, isTrue);
    expect(c.state.value, TheStates.success);

    repo.pages[2] = right(NotificationPage(items: [item(2)], hasMore: false));
    await c.retryLoadMore();
    expect(c.loadMoreFailed.value, isFalse);
    expect(c.notifications.length, 2);
  });

  testWidgets('reload replaces the list without entering loading state', (tester) async {
    repo.pages[1] = right(NotificationPage(items: [item(1)], hasMore: false));
    final c = await pump(tester);

    repo.pages[1] = right(NotificationPage(items: [item(5), item(6)], hasMore: false));
    final states = <TheStates>[];
    final worker = ever(c.state, states.add);
    await c.reload();
    worker.dispose();

    expect(states, isEmpty);
    expect(c.notifications.map((n) => n.id), [5, 6]);
  });

  testWidgets('reload failure keeps list and shows snackbar', (tester) async {
    repo.pages[1] = right(NotificationPage(items: [item(1)], hasMore: false));
    final c = await pump(tester);

    repo.pages[1] = left(const ConnectionError());
    await c.reload();
    await tester.pump();

    expect(c.state.value, TheStates.success);
    expect(c.notifications.length, 1);
    expect(find.text('Could not refresh'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('tap on unread item without url marks it read', (tester) async {
    repo.pages[1] = right(NotificationPage(items: [item(1)], hasMore: false));
    final c = await pump(tester);

    await c.onTap(c.notifications.first);

    expect(repo.markedIds, [1]);
    expect(c.notifications.first.isRead, isTrue);
  });

  testWidgets('tap on read item or item with url does nothing', (tester) async {
    repo.pages[1] = right(
      NotificationPage(
        items: [item(1, readAt: DateTime(2026)), item(2, url: 'https://x.test')],
        hasMore: false,
      ),
    );
    final c = await pump(tester);

    await c.onTap(c.notifications[0]);
    await c.onTap(c.notifications[1]);

    expect(repo.markedIds, isEmpty);
    expect(c.notifications[1].isRead, isFalse);
  });

  testWidgets('mark-read failure reverts and shows snackbar', (tester) async {
    repo.pages[1] = right(NotificationPage(items: [item(1)], hasMore: false));
    final c = await pump(tester);
    repo.markResult = left(const ApiErrorResponse(message: 'Forbidden msg', statusCode: 403, code: 'forbidden'));

    await c.onTap(c.notifications.first);
    await tester.pump();

    expect(c.notifications.first.isRead, isFalse);
    expect(find.text('Could not mark as read'), findsOneWidget);
    expect(find.text('Forbidden msg'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('mark-read 404 removes the item and shows snackbar', (tester) async {
    repo.pages[1] = right(NotificationPage(items: [item(1), item(2)], hasMore: false));
    final c = await pump(tester);
    repo.markResult = left(const ApiErrorResponse(message: 'Gone', statusCode: 404, code: 'not_found'));

    await c.onTap(c.notifications.first);
    await tester.pump();

    expect(c.notifications.map((n) => n.id), [2]);
    expect(find.text('Could not mark as read'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  test('NotificationItem.fromJson maps title/body, nullable fields and ignores data.data', () {
    final parsed = NotificationItem.fromJson({
      'id': 91,
      'type': 'push',
      'data': {'title': 'T', 'body': 'B', 'data': []},
      'read_at': null,
      'url': null,
      'created_at': '2026-09-30T09:56:45.000000Z',
    });
    expect(parsed.id, 91);
    expect(parsed.title, 'T');
    expect(parsed.body, 'B');
    expect(parsed.isRead, isFalse);
    expect(parsed.url, isNull);

    final read = NotificationItem.fromJson({
      'id': 1,
      'data': {'title': 'T', 'body': 'B'},
      'read_at': '2026-09-30T10:00:00.000000Z',
    });
    expect(read.isRead, isTrue);
  });
}
