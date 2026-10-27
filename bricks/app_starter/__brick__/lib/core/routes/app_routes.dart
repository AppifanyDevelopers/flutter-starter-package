import 'package:get/get.dart';

import '../../features/auth/presentation/bindings/auth_bindings.dart';
import '../../features/auth/presentation/screens/forgot_password_otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/signup_password_screen.dart';
import '../../features/auth/presentation/screens/signup_otp_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/dashboard/presentation/bindings/dashboard_bindings.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/notification_settings/presentation/bindings/notification_settings_bindings.dart';
import '../../features/notification_settings/presentation/screens/notification_settings_screen.dart';
import '../../features/profile/presentation/bindings/profile_bindings.dart';
import '../../features/profile/presentation/screens/change_password_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/bindings/settings_bindings.dart';
import '../../features/settings/presentation/screens/contact_us_screen.dart';
import '../../features/settings/presentation/screens/faq_screen.dart';
import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/settings/presentation/screens/terms_and_conditions_screen.dart';
import '../../features/splash/presentation/bindings/splash_bindings.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'auth_guard.dart';
import 'guest_guard.dart';

abstract class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const signupOtp = '/signup/otp';
  static const signupPassword = '/signup/password';
  static const forgotPassword = '/forgot-password';
  static const forgotPasswordOtp = '/forgot-password/otp';
  static const resetPassword = '/forgot-password/reset';
  static const dashboard = '/dashboard';
  static const faq = '/settings/faq';
  static const contactUs = '/settings/contact-us';
  static const termsAndConditions = '/settings/terms-and-conditions';
  static const privacyPolicy = '/settings/privacy-policy';
  static const notificationSettings = '/settings/notifications';
  static const changePassword = '/settings/change-password';
  static const editProfile = '/settings/edit-profile';

  static final pages = <GetPage>[
    GetPage(
      name: splash,
      page: SplashScreen.new,
      binding: SplashBindings(),
    ),
    GetPage(
      name: login,
      page: LoginScreen.new,
      binding: AuthBindings(),
      middlewares: [GuestGuard()],
    ),
    GetPage(
      name: signup,
      page: SignupScreen.new,
      binding: AuthBindings(),
      middlewares: [GuestGuard()],
    ),
    GetPage(
      name: signupOtp,
      page: SignupOtpScreen.new,
      binding: AuthBindings(),
      middlewares: [GuestGuard()],
    ),
    GetPage(
      name: signupPassword,
      page: SignupPasswordScreen.new,
      binding: AuthBindings(),
      middlewares: [GuestGuard()],
    ),
    GetPage(
      name: forgotPassword,
      page: ForgotPasswordScreen.new,
      binding: AuthBindings(),
      middlewares: [GuestGuard()],
    ),
    GetPage(
      name: forgotPasswordOtp,
      page: ForgotPasswordOtpScreen.new,
      binding: AuthBindings(),
      middlewares: [GuestGuard()],
    ),
    GetPage(
      name: resetPassword,
      page: ResetPasswordScreen.new,
      binding: AuthBindings(),
      middlewares: [GuestGuard()],
    ),
    GetPage(
      name: dashboard,
      page: DashboardScreen.new,
      binding: DashboardBindings(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: faq,
      page: FaqScreen.new,
      binding: SettingsBindings(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: contactUs,
      page: ContactUsScreen.new,
      binding: SettingsBindings(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: termsAndConditions,
      page: TermsAndConditionsScreen.new,
      binding: SettingsBindings(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: privacyPolicy,
      page: PrivacyPolicyScreen.new,
      binding: SettingsBindings(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: notificationSettings,
      page: NotificationSettingsScreen.new,
      binding: NotificationSettingsBindings(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: changePassword,
      page: ChangePasswordScreen.new,
      binding: ProfileBindings(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: editProfile,
      page: EditProfileScreen.new,
      binding: ProfileBindings(),
      middlewares: [AuthGuard()],
    ),
  ];
}
