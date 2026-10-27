import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/social_auth_service.dart';
import '../../../../core/enums/the_states.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/session/session_service.dart';
import '../../../../core/utils/keyboard.dart';
import '../../../../core/utils/pick_and_crop_image.dart';
import '../../data/repository/auth_repository.dart';

/// Drives the three signup steps, the same shared-controller-across-screens
/// shape as `ForgotPasswordController`:
///
///   1. basic details (name, email, phone, date of birth, optional photo)
///      -> sends a verification code to the email
///   2. confirm the code -> returns a verification token
///   3. choose a password -> creates the account and signs in
///
/// Google/Apple sign-up is a separate, one-shot path (see `continueWithGoogle`/
/// `continueWithApple` below) that skips all three steps -- the provider
/// already verified the email, so there's no OTP or password, and
/// phone/DOB/photo can be added later via Edit Profile. See docs/ARCHITECTURE.md.
class SignupController extends GetxController {
  SignupController(this._repository, this._socialAuthService);

  final AuthRepository _repository;
  final SocialAuthService _socialAuthService;

  // Step 1: basic details.
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final dateOfBirth = Rxn<DateTime>();
  final dobError = RxnString();
  final photoPath = Rxn<String>();
  final detailsState = TheStates.initial.obs;
  final socialState = TheStates.initial.obs;

  // Step 2: OTP.
  final otpFormKey = GlobalKey<FormState>();
  final otpController = TextEditingController();
  final otpState = TheStates.initial.obs;
  final resendState = TheStates.initial.obs;

  // Step 3: password.
  final passwordFormKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final obscurePassword = true.obs;
  final passwordState = TheStates.initial.obs;

  String? _verificationToken;

  void toggleObscurePassword() => obscurePassword.value = !obscurePassword.value;

  Future<void> pickDateOfBirth(BuildContext context) async {
    hideKeyboard();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth.value ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) {
      dateOfBirth.value = picked;
      dobError.value = null;
    }
  }

  Future<void> pickPhoto() async {
    hideKeyboard();
    final path = await pickAndCropProfilePhoto();
    if (path != null) photoPath.value = path;
  }

  /// Step 1 -> 2.
  Future<void> submitDetails() async {
    hideKeyboard();
    final formValid = formKey.currentState?.validate() ?? false;
    dobError.value = dateOfBirth.value == null ? 'Date of birth is required' : null;
    if (!formValid || dobError.value != null) return;

    detailsState.value = TheStates.loading;
    final result = await _repository.sendVerificationOtp(email: emailController.text.trim());
    await result.fold(
      (error) async {
        detailsState.value = TheStates.error;
        Get.snackbar('Could not send code', error.message);
      },
      (_) async {
        detailsState.value = TheStates.success;
        otpController.clear();
        Get.toNamed(AppRoutes.signupOtp);
      },
    );
  }

  Future<void> resendOtp() async {
    hideKeyboard();
    resendState.value = TheStates.loading;
    final result = await _repository.sendVerificationOtp(email: emailController.text.trim());
    resendState.value = TheStates.initial;
    result.fold(
      (error) => Get.snackbar('Could not send code', error.message),
      (_) => Get.snackbar('Code sent', 'Check ${emailController.text.trim()}.'),
    );
  }

  /// Step 2 -> 3.
  Future<void> verifyOtp() async {
    hideKeyboard();
    if (!(otpFormKey.currentState?.validate() ?? false)) return;

    otpState.value = TheStates.loading;
    final result = await _repository.verifySignupOtp(
      email: emailController.text.trim(),
      otp: otpController.text.trim(),
    );
    await result.fold(
      (error) async {
        otpState.value = TheStates.error;
        Get.snackbar('Invalid code', error.message);
      },
      (token) async {
        _verificationToken = token;
        otpState.value = TheStates.success;
        passwordController.clear();
        confirmPasswordController.clear();
        Get.toNamed(AppRoutes.signupPassword);
      },
    );
  }

  /// Step 3: create the account, sign in, go to the dashboard.
  Future<void> createAccount() async {
    hideKeyboard();
    if (!(passwordFormKey.currentState?.validate() ?? false)) return;
    final token = _verificationToken;
    final dob = dateOfBirth.value;
    if (token == null || dob == null) {
      Get.snackbar('Verify your email first', 'Go back and confirm the code we sent you.');
      return;
    }

    passwordState.value = TheStates.loading;
    final result = await _repository.signup(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
      phone: phoneController.text.trim(),
      dateOfBirth: dob,
      verificationToken: token,
      photoPath: photoPath.value,
    );
    await result.fold(
      (error) async {
        passwordState.value = TheStates.error;
        Get.snackbar('Signup failed', error.message);
      },
      (user) async {
        await Get.find<SessionService>().saveSession(user.token, userId: user.id);
        passwordState.value = TheStates.success;
        await AnalyticsService.logSignUp();
        Get.offAllNamed(AppRoutes.dashboard);
      },
    );
  }

  Future<void> continueWithGoogle() => _continueWithSocial(_socialAuthService.continueWithGoogle);

  Future<void> continueWithApple() => _continueWithSocial(_socialAuthService.continueWithApple);

  Future<void> _continueWithSocial(Future<Either<AppError, Unit>?> Function() action) async {
    if (socialState.value.isLoading) return;

    socialState.value = TheStates.loading;
    final result = await action();
    if (result == null) {
      socialState.value = TheStates.initial;
      return;
    }

    await result.fold(
      (error) async {
        socialState.value = TheStates.error;
        Get.snackbar('Sign-up failed', error.message);
      },
      (_) async {
        socialState.value = TheStates.success;
        await AnalyticsService.logSignUp();
        Get.offAllNamed(AppRoutes.dashboard);
      },
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    otpController.dispose();
    super.onClose();
  }
}
