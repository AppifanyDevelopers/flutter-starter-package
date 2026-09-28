sealed class AppError {
  const AppError({required this.message});

  final String message;
}

class InternalAppError extends AppError {
  const InternalAppError({required super.message});
}

class ApiErrorResponse extends AppError {
  const ApiErrorResponse({required super.message, this.statusCode});

  final int? statusCode;
}

class ConnectionError extends AppError {
  const ConnectionError({super.message = 'No internet connection. Please try again.'});
}
