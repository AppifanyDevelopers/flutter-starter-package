import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/social_auth_service.dart';
import '../../../../core/enums/the_states.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/session/session_service.dart';
import '../../../../core/utils/pick_and_crop_image.dart';
import '../../data/model/user_model.dart';
import '../../data/repository/auth_repository.dart';

/// Drives all three signup screens (account -> personal details -> OTP), the
/// same shared-controller-across-screens shape as `ForgotPasswordController`.
///
/// Google/Apple sign-up is a separate, one-shot path (see `continueWithGoogle`/
/// `continueWithApple` below) that skips steps 2/3 entirely -- the provider
/// already verified the email, so there's no OTP to send, and phone/DOB/photo
/// can be added later via Edit Profile. See docs/ARCHITECTURE.md.
class SignupController extends GetxController {
  SignupController(this._repository, this._socialAuthService);

  final AuthRepository _repository;
  final SocialAuthService _socialAuthService;

  // Step 1: account.
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final obscurePassword = true.obs;
  final socialState = TheStates.initial.obs;

  // Step 2: personal details.
  final detailsFormKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final dateOfBirth = Rxn<DateTime>();
  final photoPath = Rxn<String>();
  final detailsState = TheStates.initial.obs;

  // Step 3: OTP.
  final otpController = TextEditingController();
  final otpState = TheStates.initial.obs;

  User? _pendingUser;

  void toggleObscurePassword() => obscurePassword.value = !obscurePassword.value;

  void goToDetails() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Get.toNamed(AppRoutes.signupDetails);
  }

  Future<void> pickDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) dateOfBirth.value = picked;
  }

  Future<void> pickPhoto() async {
    final path = await pickAndCropProfilePhoto();
    if (path != null) photoPath.value = path;
  }

  Future<void> submitDetails() async {
    if (!(detailsFormKey.currentState?.validate() ?? false)) return;
    if (dateOfBirth.value == null) {
      Get.snackbar('Date of birth is required', 'Please select your date of birth.');
      return;
    }

    detailsState.value = TheStates.loading;
    final email = emailController.text.trim();
    final result = await _repository.signup(
      name: nameController.text.trim(),
      email: email,
      password: passwordController.text,
      phone: phoneController.text.trim(),
      dateOfBirth: dateOfBirth.value!,
      photoPath: photoPath.value,
    );

    await result.fold(
      (error) async {
        detailsState.value = TheStates.error;
        Get.snackbar('Signup failed', error.message);
      },
      (user) async {
        _pendingUser = user;
        await _repository.sendVerificationOtp(email: email);
        detailsState.value = TheStates.success;
        Get.toNamed(AppRoutes.signupOtp);
      },
    );
  }

  Future<void> verifyOtp() async {
    final user = _pendingUser;
    if (user == null) return;

    otpState.value = TheStates.loading;
    final result = await _repository.verifyOtp(email: emailController.text.trim(), otp: otpController.text.trim());
    await result.fold(
      (error) async {
        otpState.value = TheStates.error;
        Get.snackbar('Invalid code', error.message);
      },
      (_) async {
        await Get.find<SessionService>().saveSession(user.token);
        otpState.value = TheStates.success;
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
