class AppException implements Exception {
  const AppException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

class ServerException extends AppException {
  const ServerException([String message = 'Server error occurred', String? code])
      : super(message, code);
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Network error occurred', String? code])
      : super(message, code);
}

class AuthenticationException extends AppException {
  const AuthenticationException([String message = 'Authentication failed', String? code])
      : super(message, code);
}

class ValidationException extends AppException {
  const ValidationException([String message = 'Validation failed', String? code])
      : super(message, code);
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'Resource not found', String? code])
      : super(message, code);
}

class PermissionException extends AppException {
  const PermissionException([String message = 'Permission denied', String? code])
      : super(message, code);
}

class CacheException extends AppException {
  const CacheException([String message = 'Cache error occurred', String? code])
      : super(message, code);
}
