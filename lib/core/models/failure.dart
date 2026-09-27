import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

@freezed
class Failure with _$Failure {
  const factory Failure.serverError(String message) = _ServerError;
  const factory Failure.networkError(String message) = _NetworkError;
  const factory Failure.authenticationError(String message) = _AuthenticationError;
  const factory Failure.validationError(String message) = _ValidationError;
  const factory Failure.notFoundError(String message) = _NotFoundError;
  const factory Failure.permissionError(String message) = _PermissionError;
  const factory Failure.unknownError(String message) = _UnknownError;
}

extension FailureExtension on Failure {
  String get message {
    return when(
      serverError: (msg) => msg,
      networkError: (msg) => msg,
      authenticationError: (msg) => msg,
      validationError: (msg) => msg,
      notFoundError: (msg) => msg,
      permissionError: (msg) => msg,
      unknownError: (msg) => msg,
    );
  }
}
