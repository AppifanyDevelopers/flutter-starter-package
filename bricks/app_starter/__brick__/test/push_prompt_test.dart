import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:{{project_name}}/core/errors/app_error.dart';
import 'package:{{project_name}}/core/notifications/device_token_repository.dart';
import 'package:{{project_name}}/core/notifications/push_permission_prompt.dart';
import 'package:{{project_name}}/core/session/session_service.dart';

class _Session extends SessionService {
  @override
  Future<void> saveSession(String token, {String? userId}) async => markLoggedInForTest();
}

class _TokenRepo implements DeviceTokenRepository {
  final registered = <String>[];

  @override
  Future<Either<AppError, Unit>> register(String deviceToken) async {
    registered.add(deviceToken);
    return right(unit);
  }
}

void main() {
  late _Session session;

  Future<void> pumpHost(WidgetTester tester) async {
    Get.testMode = true;
    Get.reset();
    session = _Session();
    Get.put<SessionService>(session);
    Get.put<DeviceTokenRepository>(_TokenRepo());
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: Text('dashboard'))));
  }

  testWidgets('no prompt unless a login just happened', (tester) async {
    await pumpHost(tester);
    PushPermissionPrompt.showIfPending();
    await tester.pumpAndSettle();
    expect(find.text('Turn on notifications?'), findsNothing);
  });

  testWidgets('after login the dialog offers Turn on or Later, once', (tester) async {
    await pumpHost(tester);
    await session.saveSession('t');

    final done = PushPermissionPrompt.showIfPending();
    await tester.pumpAndSettle();
    expect(find.text('Turn on notifications?'), findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    await done;
    expect(find.text('Turn on notifications?'), findsNothing);

    // Offered once per login: asking again without a new login does nothing.
    PushPermissionPrompt.showIfPending();
    await tester.pumpAndSettle();
    expect(find.text('Turn on notifications?'), findsNothing);
  });

  testWidgets('Turn on closes the dialog and is safe without Firebase', (tester) async {
    await pumpHost(tester);
    await session.saveSession('t');

    final done = PushPermissionPrompt.showIfPending();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    await done;

    expect(find.text('Turn on notifications?'), findsNothing);
    // No Firebase in tests -> permission is "not granted" -> nothing registered.
    expect((Get.find<DeviceTokenRepository>() as _TokenRepo).registered, isEmpty);
  });
}
