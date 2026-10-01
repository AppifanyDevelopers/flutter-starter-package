sealed class AppError {
  const AppError({required this.message});

  final String message;
}

class InternalAppError extends AppError {
  const InternalAppError({required super.message});
}

/// An error response from the backend. Branch on [code] (stable), never on
/// [message] (may be reworded); [message] is always safe to show the user.
class ApiErrorResponse extends AppError {
  const ApiErrorResponse({
    required super.message,
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
  });

  final int? statusCode;

  /// Machine-readable code such as `invalid_credentials` or `validation_failed`.
  final String? code;

  /// Field name -> messages, present for validation and OTP errors.
  final Map<String, List<String>> fieldErrors;

  /// From the `Retry-After` header on 429 and OTP resend-cooldown responses.
  final int? retryAfterSeconds;

  /// The first message for [field], for showing under a form field.
  String? firstError(String field) {
    final messages = fieldErrors[field];
    return messages == null || messages.isEmpty ? null : messages.first;
  }

  /// Token missing, invalid, expired or logged out on a protected endpoint.
  bool get isUnauthenticated => statusCode == 401 && code == 'unauthenticated';

  bool get isValidationFailed => code == 'validation_failed';

  bool get isRateLimited => statusCode == 429;

  bool get isMaintenance => statusCode == 503;
}

class ConnectionError extends AppError {
  const ConnectionError({super.message = 'No internet connection. Please try again.'});
}
