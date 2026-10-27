import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:{{project_name}}/core/auth/social_auth_service.dart';
import 'package:{{project_name}}/core/errors/app_error.dart';
import 'package:{{project_name}}/core/routes/app_routes.dart';
import 'package:{{project_name}}/core/session/session_service.dart';
import 'package:{{project_name}}/features/auth/data/model/user_model.dart';
import 'package:{{project_name}}/features/auth/data/repository/fake_auth_repository.dart';
import 'package:{{project_name}}/features/auth/presentation/controllers/signup_controller.dart';
import 'package:{{project_name}}/features/auth/presentation/screens/signup_otp_screen.dart';
import 'package:{{project_name}}/features/auth/presentation/screens/signup_password_screen.dart';
import 'package:{{project_name}}/features/auth/presentation/screens/signup_screen.dart';

class _RecordingRepo extends FakeAuthRepository {
  final calls = <String>[];
  String? signupToken;

  @override
  Future<Either<AppError, Unit>> sendVerificationOtp({required String email}) {
    calls.add('send');
    return super.sendVerificationOtp(email: email);
  }

  @override
  Future<Either<AppError, String>> verifySignupOtp({required String email, required String otp}) {
    calls.add('verify');
    return super.verifySignupOtp(email: email, otp: otp);
  }

  @override
  Future<Either<AppError, User>> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required DateTime dateOfBirth,
    required String verificationToken,
    String? photoPath,
  }) {
    calls.add('signup');
    signupToken = verificationToken;
    return super.signup(
      name: name,
      email: email,
      password: password,
      phone: phone,
      dateOfBirth: dateOfBirth,
      verificationToken: verificationToken,
      photoPath: photoPath,
    );
  }
}

class _FakeSession extends SessionService {
  String? savedToken;

  @override
  Future<void> saveSession(String token) async => savedToken = token;
}

void main() {
  late _RecordingRepo repo;
  late _FakeSession session;
  late SignupController controller;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Get.testMode = true;
    Get.reset();
    repo = _RecordingRepo();
    session = _FakeSession();
    Get.put<SessionService>(session);
    controller = Get.put(SignupController(repo, SocialAuthService(repo, session)));

    await tester.pumpWidget(GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.signup,
      getPages: [
        GetPage(name: AppRoutes.signup, page: SignupScreen.new),
        GetPage(name: AppRoutes.signupOtp, page: SignupOtpScreen.new),
        GetPage(name: AppRoutes.signupPassword, page: SignupPasswordScreen.new),
        GetPage(name: AppRoutes.dashboard, page: () => const Scaffold(body: Text('DASHBOARD'))),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(seconds: 5));

  Future<void> fillDetails(WidgetTester tester, {String name = 'Jane Doe', String email = 'jane@example.com', String phone = '0412 345 678'}) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), name);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone number'), phone);
  }

  testWidgets('step 1 is basic details, labelled 1 of 3', (tester) async {
    await pumpApp(tester);
    expect(find.text('Step 1 of 3: Basic details'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    // No password on step 1.
    expect(find.text('Password'), findsNothing);
    // Google and Apple only (Apple renders on iOS), no other providers.
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.textContaining('Facebook'), findsNothing);
  });

  testWidgets('step 1 with blank/space-only fields stays put and shows errors', (tester) async {
    await pumpApp(tester);
    await fillDetails(tester, name: '   ', email: '   ', phone: '   ');
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Date of birth is required'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(find.text('Step 1 of 3: Basic details'), findsOneWidget);
  });

  testWidgets('errors do not appear while typing', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'nope');
    await tester.pump();
    expect(find.text('Enter a valid email'), findsNothing);
  });

  testWidgets('step 1 needs a date of birth', (tester) async {
    await pumpApp(tester);
    await fillDetails(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Date of birth is required'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('full flow: details -> OTP -> password -> dashboard, in that order', (tester) async {
    await pumpApp(tester);

    // Step 1
    await fillDetails(tester);
    controller.dateOfBirth.value = DateTime(1990, 5, 17);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(repo.calls, ['send']);
    expect(find.text('Step 2 of 3: Confirm code'), findsOneWidget);

    // Step 2: wrong code stays, blank code is a validation error.
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Verification code is required'), findsOneWidget);
    expect(repo.calls, ['send']);

    await tester.enterText(find.widgetWithText(TextFormField, 'Verification code'), '9999');
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Step 2 of 3: Confirm code'), findsOneWidget);
    expect(repo.calls, ['send', 'verify']);

    await tester.enterText(find.widgetWithText(TextFormField, 'Verification code'), '1234');
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Step 3 of 3: Password'), findsOneWidget);
    // The account must NOT exist before the password step.
    expect(repo.calls, ['send', 'verify', 'verify']);
    expect(session.savedToken, isNull);

    // Step 3: weak passwords are rejected, one rule at a time.
    Future<void> tryPassword(String p, String error) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), p);
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), p);
      await tester.tap(find.text('Create account'));
      await settle(tester);
      expect(find.text(error), findsOneWidget, reason: p);
      expect(repo.calls.contains('signup'), isFalse, reason: p);
    }

    await tryPassword('   ', 'Password cannot be only spaces');
    await tryPassword('Pa0!', 'Password must be at least 8 characters');
    await tryPassword('passw0rd!', 'Password needs a capital letter');
    await tryPassword('Password!', 'Password needs a number');
    await tryPassword('Passw0rdd', 'Password needs a special character');
    await tryPassword('Pass w0rd!', 'Password must not contain spaces');

    // Mismatch
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Passw0rd!');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'Passw0rd?');
    await tester.tap(find.text('Create account'));
    await settle(tester);
    expect(find.text('Passwords do not match'), findsOneWidget);

    // Success
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'Passw0rd!');
    await tester.tap(find.text('Create account'));
    await settle(tester);

    expect(repo.calls.last, 'signup');
    expect(repo.signupToken, 'fake-verification-token');
    expect(session.savedToken, isNotNull);
    expect(find.text('DASHBOARD'), findsOneWidget);
  });
}
