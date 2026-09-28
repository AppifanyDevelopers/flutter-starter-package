import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In closed without a credential (user canceled, UI interrupted,
/// the platform UI wasn't available, etc.) -- not a real error to surface.
bool isGoogleSignInUserDismissal(GoogleSignInException e) {
  switch (e.code) {
    case GoogleSignInExceptionCode.canceled:
    case GoogleSignInExceptionCode.interrupted:
    case GoogleSignInExceptionCode.uiUnavailable:
      return true;
    default:
      return false;
  }
}

/// Defensive fallback for a canceled Apple authorization surfacing through
/// something other than the typed `SignInWithAppleAuthorizationException`
/// (which is already checked directly) -- a substring check on the
/// stringified exception, same net rentsy_customer keeps for the same reason.
bool isAppleAuthorizationCanceledMessage(String message) {
  return message.contains('authorization-error/canceled');
}
