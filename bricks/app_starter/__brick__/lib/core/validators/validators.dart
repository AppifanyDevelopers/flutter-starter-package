/// Form validators. Every one works on the trimmed value, so a field holding
/// only spaces is "empty" -- the form never needs `.trim()` to be correct.
///
/// Forms validate only on submit (see `AppTextFormField`), never while typing.
abstract class Validators {
  Validators._();

  static final _emailPattern = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');
  static final _phonePattern = RegExp(r'^\+?[0-9][0-9 \-]{6,18}[0-9]$');

  static String? Function(String?) required(String label) => (value) {
        if (value == null || value.trim().isEmpty) return '$label is required';
        return null;
      };

  static String? Function(String?) name() => (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Name is required';
        if (v.length < 2) return 'Enter your full name';
        return null;
      };

  static String? Function(String?) email() => (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Email is required';
        if (!_emailPattern.hasMatch(v)) return 'Enter a valid email';
        return null;
      };

  static String? Function(String?) phone() => (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Phone number is required';
        if (!_phonePattern.hasMatch(v)) return 'Enter a valid phone number';
        return null;
      };

  static String? Function(String?) optionalPhone() => (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return null;
        return _phonePattern.hasMatch(v) ? null : 'Enter a valid phone number';
      };

  static String? Function(String?) otp({int length = 4}) => (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Verification code is required';
        if (!RegExp('^[0-9]{$length}\$').hasMatch(v)) return 'Enter the $length-digit code';
        return null;
      };

  /// For *entering* an existing password (login, current password): it only
  /// has to be non-blank. The strength rules apply when *creating* one.
  static String? Function(String?) requiredPassword([String label = 'Password']) => (value) {
        if (value == null || value.trim().isEmpty) return '$label is required';
        return null;
      };

  /// For creating/changing a password. Mirrors [PasswordRules].
  static String? Function(String?) newPassword() => (value) {
        if (value == null || value.isEmpty) return 'Password is required';
        if (value.trim().isEmpty) return 'Password cannot be only spaces';
        if (PasswordRules.hasSpace(value)) return 'Password must not contain spaces';
        if (!PasswordRules.hasMinLength(value)) {
          return 'Password must be at least ${PasswordRules.minLength} characters';
        }
        if (!PasswordRules.hasUppercase(value)) return 'Password needs a capital letter';
        if (!PasswordRules.hasNumber(value)) return 'Password needs a number';
        if (!PasswordRules.hasSpecial(value)) return 'Password needs a special character';
        return null;
      };

  static String? Function(String?) confirmPassword(String Function() passwordGetter) => (value) {
        if (value == null || value.isEmpty) return 'Please confirm your password';
        if (value != passwordGetter()) return 'Passwords do not match';
        return null;
      };
}

/// The password rules, in one place so the validator and the on-screen
/// checklist can never disagree.
abstract class PasswordRules {
  PasswordRules._();

  static const minLength = 8;

  static bool hasMinLength(String v) => v.length >= minLength;
  static bool hasUppercase(String v) => RegExp(r'[A-Z]').hasMatch(v);
  static bool hasNumber(String v) => RegExp(r'[0-9]').hasMatch(v);
  static bool hasSpecial(String v) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(v);
  static bool hasSpace(String v) => RegExp(r'\s').hasMatch(v);
  static bool noSpaces(String v) => v.isNotEmpty && !hasSpace(v);

  static bool isValid(String v) =>
      hasMinLength(v) && hasUppercase(v) && hasNumber(v) && hasSpecial(v) && noSpaces(v);
}
