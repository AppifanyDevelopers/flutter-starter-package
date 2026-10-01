import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:verify_app/core/auth/social_auth_service.dart';
import 'package:verify_app/core/config/app_configuration.dart';
import 'package:verify_app/core/enums/the_states.dart';
import 'package:verify_app/core/errors/app_error.dart';
import 'package:verify_app/core/network/dio_api_client.dart';
import 'package:verify_app/core/session/session_service.dart';
import 'package:verify_app/features/auth/data/model/user_model.dart';
import 'package:verify_app/features/auth/data/repository/dio_auth_repository.dart';
import 'package:verify_app/features/auth/data/repository/fake_auth_repository.dart';
import 'package:verify_app/features/auth/presentation/controllers/login_controller.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _successBody = {
  'status': 200,
  'message': null,
  'data': {
    'access_token': 'jwt-abc',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': 36,
      'name': 'Sample User',
      'email': 'sample.user@example.com',
      'phone': null,
      'avatar': null,
      'location': null,
      'subscription_type': null,
      'is_blocked': false,
      'is_approved': true,
      'approved_at': '2026-09-30T09:56:44+00:00',
      'blocked_at': null,
      'created_at': '2026-09-30T09:56:44+00:00',
      'updated_at': '2026-09-30T09:56:44+00:00',
    },
  },
};

DioAuthRepository _repo(_StubAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return DioAuthRepository(DioApiClient(dio));
}

class _FakeSession implements SessionService {
  String? savedToken;
  @override
  String? get rememberedEmail => null;
  @override
  Future<void> saveSession(String token) async => savedToken = token;
  @override
  Future<void> setRememberedEmail(String? email) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScriptedRepo extends FakeAuthRepository {
  _ScriptedRepo(this.results);
  final List<Either<AppError, User>> results;
  final emails = <String>[];

  @override
  Future<Either<AppError, User>> login({required String email, required String password}) async {
    emails.add(email);
    return results.removeAt(0);
  }
}

const _validation = ApiErrorResponse(
  message: 'The email field is required. (and 1 more error)',
  statusCode: 422,
  code: 'validation_failed',
  fieldErrors: {
    'email': ['The email field is required.'],
    'password': ['The password field is required.'],
  },
);

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api');
    AppConfiguration.current = AppConfiguration.staging;
  });

  group('DioAuthRepository.login', () {
    test('maps data.access_token and data.user to User with String id', () async {
      final adapter = _StubAdapter(200, _successBody);
      final result = await _repo(adapter).login(email: 'a@b.co', password: 'pw');

      final user = result.getOrElse(() => throw StateError('expected success'));
      expect(user.id, '36');
      expect(user.name, 'Sample User');
      expect(user.email, 'sample.user@example.com');
      expect(user.token, 'jwt-abc');
      expect(adapter.last!.path, '/auth/login');
      expect(adapter.last!.method, 'POST');
    });

    test('sends the email trimmed and lowercased, with no device fields', () async {
      final adapter = _StubAdapter(200, _successBody);
      await _repo(adapter).login(email: '  Sample.User@Example.COM ', password: 'Secret1');

      expect(adapter.last!.data, {'email': 'sample.user@example.com', 'password': 'Secret1'});
    });

    test('401 invalid_credentials surfaces the backend message', () async {
      final adapter = _StubAdapter(401, {
        'status': 401,
        'code': 'invalid_credentials',
        'message': 'Invalid email or password.',
        'errors': null,
      });
      final result = await _repo(adapter).login(email: 'a@b.co', password: 'bad');

      final error = result.swap().getOrElse(() => throw StateError('expected failure'));
      expect(error, isA<ApiErrorResponse>());
      expect(error.message, 'Invalid email or password.');
      expect((error as ApiErrorResponse).code, 'invalid_credentials');
    });

    test('422 keeps field errors', () async {
      final adapter = _StubAdapter(422, {
        'status': 422,
        'code': 'validation_failed',
        'message': 'The email field is required. (and 1 more error)',
        'errors': {
          'email': ['The email field is required.'],
          'password': ['The password field is required.'],
        },
      });
      final result = await _repo(adapter).login(email: '', password: '');

      final error = result.swap().getOrElse(() => throw StateError('expected failure')) as ApiErrorResponse;
      expect(error.firstError('email'), 'The email field is required.');
      expect(error.firstError('password'), 'The password field is required.');
    });
  });

  group('LoginController', () {
    late _FakeSession session;

    setUp(() {
      Get.reset();
      session = _FakeSession();
      Get.put<SessionService>(session);
    });

    tearDown(Get.reset);

    Future<(LoginController, _ScriptedRepo)> pump(WidgetTester tester, List<Either<AppError, User>> results) async {
      final repo = _ScriptedRepo(results);
      final controller = LoginController(repo, SocialAuthService(repo, session));
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Form(
              key: controller.formKey,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      controller.emailController.text = 'User@Example.com';
      controller.passwordController.text = 'pw';
      return (controller, repo);
    }

    testWidgets('422 field errors reach emailError and passwordError, no snackbar needed', (tester) async {
      final (controller, _) = await pump(tester, [left(_validation)]);

      await controller.login();
      await tester.pump();

      expect(controller.emailError.value, 'The email field is required.');
      expect(controller.passwordError.value, 'The password field is required.');
      expect(controller.state.value.isError, isTrue);
    });

    testWidgets('a new attempt clears old field errors', (tester) async {
      final (controller, _) = await pump(tester, [
        left(_validation),
        left(const ApiErrorResponse(message: 'Invalid email or password.', statusCode: 401, code: 'invalid_credentials')),
      ]);

      await controller.login();
      await tester.pump();
      expect(controller.emailError.value, isNotNull);

      await controller.login();
      await tester.pump();
      expect(controller.emailError.value, isNull);
      expect(controller.passwordError.value, isNull);
      expect(find.text('Invalid email or password.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('401 invalid_credentials shows the message in a snackbar and sets no field errors', (tester) async {
      final (controller, _) = await pump(tester, [
        left(const ApiErrorResponse(message: 'Invalid email or password.', statusCode: 401, code: 'invalid_credentials')),
      ]);

      await controller.login();
      await tester.pump();

      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(controller.emailError.value, isNull);
      expect(controller.passwordError.value, isNull);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
