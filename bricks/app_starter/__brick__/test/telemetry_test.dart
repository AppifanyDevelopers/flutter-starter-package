import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:{{project_name}}/core/auth/social_auth_service.dart';
import 'package:{{project_name}}/core/config/app_configuration.dart';
import 'package:{{project_name}}/core/network/dio_api_client.dart';
import 'package:{{project_name}}/core/routes/app_routes.dart';
import 'package:{{project_name}}/core/session/session_service.dart';
import 'package:{{project_name}}/core/telemetry/telemetry.dart';
import 'package:{{project_name}}/features/auth/data/repository/fake_auth_repository.dart';
import 'package:{{project_name}}/features/auth/presentation/controllers/login_controller.dart';
import 'package:{{project_name}}/features/auth/presentation/screens/login_screen.dart';

class _Sink implements TelemetrySink {
  final events = <String>[];

  @override
  Future<void> setFlavor(String flavor) async => events.add('flavor:$flavor');
  @override
  Future<void> identify(String userId) async => events.add('identify:$userId');
  @override
  Future<void> clearUser() async => events.add('clear');
  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) async =>
      events.add('error:$reason');
}

/// Answers every request with [status].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(body, status, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Sink sink;

  setUp(() {
    sink = _Sink();
    Telemetry.sink = sink;
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => Telemetry.sink = FirebaseTelemetrySink());

  group('session identity', () {
    test('saving a session with a user id identifies the user', () async {
      await SessionService().saveSession('tok', userId: '42');
      expect(sink.events, ['identify:42']);
    });

    test('saving a session without a user id identifies nobody', () async {
      await SessionService().saveSession('tok');
      expect(sink.events, isEmpty);
    });

    test('a returning user is identified again after a restart', () async {
      await SessionService().saveSession('tok', userId: '42');
      sink.events.clear();

      final restarted = SessionService(); // new process, same secure storage
      await restarted.hydrate();
      expect(restarted.isLoggedInSync, isTrue);
      expect(sink.events, ['identify:42']);
    });

    test('a logged-out user is not identified on restart', () async {
      final session = SessionService();
      await session.saveSession('tok', userId: '42');
      await session.clear();
      expect(sink.events, ['identify:42', 'clear']);

      sink.events.clear();
      await SessionService().hydrate();
      expect(sink.events, isEmpty);
    });
  });

  group('server errors', () {
    DioApiClient clientFor(int status) {
      dotenv.testLoad(fileInput: 'API_BASE_URL=https://api.test/api');
      AppConfiguration.current = AppConfiguration.staging;
      final dio = Dio()..httpClientAdapter = _Adapter(status, '{"status":$status,"code":"x","message":"m","errors":null}');
      return DioApiClient(dio);
    }

    test('a 500 is reported with the request that failed', () async {
      final result = await clientFor(500).get('/profile');
      expect(result.isLeft(), isTrue);
      expect(sink.events, ['error:GET /profile -> 500']);
    });

    test('expected 4xx outcomes are not reported', () async {
      for (final status in [401, 403, 404, 422, 429]) {
        await clientFor(status).get('/profile');
      }
      expect(sink.events, isEmpty);
    });
  });

  testWidgets('logging in identifies the user', (tester) async {
    Get.testMode = true;
    Get.reset();
    final repo = FakeAuthRepository();
    final session = SessionService();
    Get.put(session);
    Get.put(LoginController(repo, SocialAuthService(repo, session)));

    await tester.pumpWidget(GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.login,
      getPages: [
        GetPage(name: AppRoutes.login, page: LoginScreen.new),
        GetPage(name: AppRoutes.dashboard, page: () => const Scaffold(body: Text('DASHBOARD'))),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'demo@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(sink.events, ['identify:demo-user-1']);
  });
}
