/// Endpoint paths, relative to the API base URL (which ends in `/api` for the
/// reference backend -- see `docs/ai/api-workflow/BACKEND_CONTRACT.md`). Nothing
/// reads these yet -- every repository is still fake (see the
/// `TODO(swap-backend)` markers throughout `lib/features/*/data/repository/`)
/// -- but a real implementation should have a matching path here rather than
/// a magic string buried in the request call.
abstract class AppEndpoints {
  AppEndpoints._();

  // Auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const refreshToken = '/auth/refresh';
  static const logout = '/auth/logout';
  static const forgotPassword = '/auth/password/forgot';
  static const verifyResetOtp = '/auth/password/verify';
  static const resendResetOtp = '/auth/password/resend';
  static const resetPassword = '/auth/password/reset';

  // Profile
  static const profile = '/profile';
  static const currentUser = '/user';
  static const changePassword = '/change-password';
  static const deviceTokens = '/device-tokens';

  // Notifications
  static const notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';
  static const notificationsMarkAllRead = '/notifications/mark-all-as-read';

  // Content and support
  static const faqs = '/faqs';
  static const termsAndConditions = '/terms_and_conditions';
  static const privacyPolicy = '/privacy_policy';
  static const communityGuidelines = '/community_guidelines';
  static const contactUs = '/contact-us';

  // Not provided by the reference backend -- keep only if yours has them.
  static const sendVerificationOtp = '/auth/otp/send';
  static const verifyOtp = '/auth/otp/verify';
  static const deleteAccount = '/profile';
  static const notificationPreferences = '/notification-preferences';
}
