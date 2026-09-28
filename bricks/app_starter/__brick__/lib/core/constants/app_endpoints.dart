/// Reference endpoint paths for when a `Fake*Repository` is swapped for a
/// real `Dio*Repository` (see `TODO(swap-backend)` markers throughout
/// `lib/features/*/data/repository/`). Nothing reads these yet -- every
/// repository is still fake -- but a real implementation should have a
/// matching path here rather than a magic string buried in the request call.
abstract class AppEndpoints {
  AppEndpoints._();

  // Auth
  static const login = '/auth/login';
  static const signup = '/auth/signup';
  static const sendVerificationOtp = '/auth/otp/send';
  static const verifyOtp = '/auth/otp/verify';
  static const forgotPassword = '/auth/password/forgot';
  static const resetPassword = '/auth/password/reset';

  // Profile
  static const profile = '/profile';
  static const changePassword = '/profile/password';
  static const deleteAccount = '/profile';

  // Settings content
  static const faqs = '/content/faqs';
  static const contactUs = '/content/contact-us';
  static const termsAndConditions = '/content/terms-and-conditions';
  static const privacyPolicy = '/content/privacy-policy';

  // Notification settings
  static const notificationPreferences = '/notification-preferences';
}
