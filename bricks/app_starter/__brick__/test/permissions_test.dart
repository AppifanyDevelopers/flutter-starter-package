import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:{{project_name}}/core/permissions/permissions.dart';

class _Gateway implements PermissionGateway {
  _Gateway({required this.current, this.afterRequest = PermissionOutcome.denied});

  PermissionOutcome current;
  final PermissionOutcome afterRequest;
  var requests = 0;
  var openedSettings = 0;

  @override
  Future<PermissionOutcome> status(AppPermission permission) async => current;

  @override
  Future<PermissionOutcome> request(AppPermission permission) async {
    requests++;
    return current = afterRequest;
  }

  @override
  Future<bool> openSettings() async {
    openedSettings++;
    return true;
  }
}

void main() {
  late PermissionGateway original;

  setUp(() => original = Permissions.gateway);
  tearDown(() => Permissions.gateway = original);

  Future<void> host(WidgetTester tester) async {
    Get.testMode = true;
    Get.reset();
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: Text('home'))));
  }

  testWidgets('already granted: true, no prompt, no dialog', (tester) async {
    await host(tester);
    final gateway = _Gateway(current: PermissionOutcome.granted);
    Permissions.gateway = gateway;

    expect(await Permissions.ensure(AppPermission.camera), isTrue);
    expect(gateway.requests, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('not decided and the user allows: true after one system prompt', (tester) async {
    await host(tester);
    final gateway = _Gateway(current: PermissionOutcome.denied, afterRequest: PermissionOutcome.granted);
    Permissions.gateway = gateway;

    expect(await Permissions.ensure(AppPermission.camera), isTrue);
    expect(gateway.requests, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('not decided and the user declines once: false, no settings dialog yet', (tester) async {
    await host(tester);
    final gateway = _Gateway(current: PermissionOutcome.denied, afterRequest: PermissionOutcome.denied);
    Permissions.gateway = gateway;

    expect(await Permissions.ensure(AppPermission.camera), isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(gateway.openedSettings, 0);
  });

  testWidgets('denied for good: explains and can open Settings', (tester) async {
    await host(tester);
    final gateway = _Gateway(current: PermissionOutcome.permanentlyDenied);
    Permissions.gateway = gateway;

    final result = Permissions.ensure(AppPermission.camera);
    await tester.pumpAndSettle();
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.textContaining('take a photo'), findsOneWidget);
    expect(gateway.requests, 0, reason: 'the system will not prompt again, so do not try');

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(gateway.openedSettings, 1);
  });

  testWidgets('denied for good and the user says "Not now": Settings stays closed', (tester) async {
    await host(tester);
    final gateway = _Gateway(current: PermissionOutcome.permanentlyDenied);
    Permissions.gateway = gateway;

    final result = Permissions.ensure(AppPermission.notifications);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
    expect(gateway.openedSettings, 0);
  });

  testWidgets('declining in the system prompt, then permanently, leads to the dialog next time', (tester) async {
    await host(tester);
    final gateway = _Gateway(current: PermissionOutcome.denied, afterRequest: PermissionOutcome.permanentlyDenied);
    Permissions.gateway = gateway;

    final result = Permissions.ensure(AppPermission.photos);
    await tester.pumpAndSettle();
    expect(find.text('Photos access is off'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(gateway.requests, 1);
  });
}
