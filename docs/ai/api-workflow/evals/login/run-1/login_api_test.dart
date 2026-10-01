import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:verify_app/core/auth/social_auth_service.dart';
import 'package:verify_app/core/config/app_configuration.dart';
import 'package:verify_app/core/constants/app_endpoints.dart';
import 'package:verify_app/core/enums/the_states.dart';
import 'package:verify_app/core/errors/app_error.dart';
import 'package:verify_app/core/network/dio_api_client.dart';
import 'package:verify_app/core/session/session_service.dart';
import 'package:verify_app/features/auth/data/model/user_model.dart';
import 'package:verify_app/features/auth/data/repository/dio_auth_repository.dart';
import 'package:verify_app/features/auth/data/repository/fake_auth_repository.dart';
import 'package:verify_app/features/auth/presentation/controllers/login_controller.dart';

import 'login_api_test_support.dart';

void main() {
  group('DioAuthRepository.login', () {
    late StubAdapter adapter;
    late DioAuthRepository repo;

    setUp(() {
      dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api');
      AppConfiguration.current = AppConfiguration.staging;
      adapter = StubAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      repo = DioAuthRepository(DioApiClient(dio), FakeAuthRepository());
    });

    test('maps data.access_token and data.user to User', () async {
      adapter.reply(200, {
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
            'blocked_at': null,
          },
        },
      });
      final result = await repo.login(email: 'sample.user@example.com', password: 'pw');
      final user = result.getOrElse(() => throw StateError('expected right'));
      expect(user.id, '36');
      expect(user.name, 'Sample User');
      expect(user.email, 'sample.user@example.com');
      expect(user.token, 'jwt-abc');
      expect(adapter.lastPath, endsWith(AppEndpoints.login));
      expect(adapter.lastBody, {'email': 'sample.user@example.com', 'password': 'pw'});
    });

    test('401 invalid_credentials surfaces code and message', () async {
      adapter.reply(401, {
        'status': 401,
        'code': 'invalid_credentials',
        'message': 'Invalid email or password.',
        'errors': null,
      });
      final result = await repo.login(email: 'a@b.co', password: 'x');
      final error = result.swap().getOrElse(() => throw StateError('expected left')) as ApiErrorResponse;
      expect(error.code, 'invalid_credentials');
      expect(error.message, 'Invalid email or password.');
    });

    test('success without a token is an error, not a crash', () async {
      adapter.reply(200, {'status': 200, 'message': null, 'data': null});
      final result = await repo.login(email: 'a@b.co', password: 'x');
      expect(result.isLeft(), isTrue);
    });
  });

  group('LoginController', () {
    late _ScriptedRepository repo;
    late LoginController controller;

    setUp(() {
      Get.reset();
      Get.put<SessionService>(_FakeSession());
      repo = _ScriptedRepository();
      controller = LoginController(repo, SocialAuthService(repo, Get.find()));
      controller.emailController.text = 'a@b.co';
      controller.passwordController.text = 'password1';
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: Form(key: controller.formKey, child: const SizedBox())),
          getPages: [GetPage(name: '/dashboard', page: () => const SizedBox())],
        ),
      );
    }

    testWidgets('422 field errors reach emailError/passwordError', (tester) async {
      await pump(tester);
      repo.next = left(const ApiErrorResponse(
        message: 'The email field is required. (and 1 more error)',
        statusCode: 422,
        code: 'validation_failed',
        fieldErrors: {
          'email': ['The email field is required.'],
          'password': ['The password field is required.'],
        },
      ));
      await controller.login();
      expect(controller.emailError.value, 'The email field is required.');
      expect(controller.passwordError.value, 'The password field is required.');
      expect(controller.state.value, TheStates.error);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a new attempt clears old field errors', (tester) async {
      await pump(tester);
      repo.next = left(const ApiErrorResponse(
        message: 'x',
        statusCode: 422,
        code: 'validation_failed',
        fieldErrors: {'email': ['bad email']},
      ));
      await controller.login();
      expect(controller.emailError.value, 'bad email');

      repo.next = left(const ApiErrorResponse(
        message: 'Invalid email or password.',
        statusCode: 401,
        code: 'invalid_credentials',
      ));
      await controller.login();
      expect(controller.emailError.value, isNull);
      expect(controller.passwordError.value, isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('401 invalid_credentials shows message in a snackbar, no field errors', (tester) async {
      await pump(tester);
      repo.next = left(const ApiErrorResponse(
        message: 'Invalid email or password.',
        statusCode: 401,
        code: 'invalid_credentials',
      ));
      await controller.login();
      await tester.pump();
      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(controller.emailError.value, isNull);
      expect(controller.passwordError.value, isNull);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}

class _ScriptedRepository extends FakeAuthRepository {
  Either<AppError, User> next = left(const InternalAppError(message: 'unset'));

  @override
  Future<Either<AppError, User>> login({required String email, required String password}) async => next;
}

class _FakeSession implements SessionService {
  @override
  String? get rememberedEmail => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
