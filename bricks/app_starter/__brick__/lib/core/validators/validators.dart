import 'package:form_validator/form_validator.dart';

abstract class Validators {
  Validators._();

  static String? Function(String?) email() =>
      ValidationBuilder().required('Email is required').email('Enter a valid email').build();

  static String? Function(String?) password({int minLength = 8}) => ValidationBuilder()
      .required('Password is required')
      .minLength(minLength, 'Password must be at least $minLength characters')
      .build();

  static String? Function(String?) required(String label) =>
      ValidationBuilder().required('$label is required').build();

  static String? Function(String?) phone() =>
      ValidationBuilder().required('Phone number is required').phone('Enter a valid phone number').build();

  static String? Function(String?) confirmPassword(String Function() passwordGetter) {
    return (value) {
      if (value == null || value.isEmpty) return 'Please confirm your password';
      if (value != passwordGetter()) return 'Passwords do not match';
      return null;
    };
  }
}
