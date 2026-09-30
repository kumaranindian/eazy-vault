import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../exceptions/app_exception.dart';

/// Converts technical errors (Firebase, platform, Dart) into short messages
/// that are safe to show to the user. Log the original error separately.
class ErrorMessages {
  const ErrorMessages._();

  static const String connection =
      'Unable to connect to the server. Please check your internet connection and try again.';
  static const String permission =
      "You don't have permission to perform this action.";
  static const String timeout = 'The request timed out. Please try again.';
  static const String sessionExpired =
      'Your session has expired. Please sign in again.';
  static const String generic = 'Something went wrong. Please try again.';

  /// [action] describes what the user was doing, e.g. `'load your accounts'`,
  /// and is used for the fallback message ("Couldn't load your accounts…").
  static String from(Object error, {String? action}) {
    if (error is AppException) return error.message;

    if (error is FirebaseException) {
      final known = _forCode(error.code);
      if (known != null) return known;
    }

    if (error is TimeoutException) return timeout;

    final text = error.toString().toLowerCase();
    if (text.contains('socketexception') ||
        text.contains('xmlhttprequest') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('offline')) {
      return connection;
    }
    if (text.contains('permission-denied') ||
        text.contains('permission_denied')) {
      return permission;
    }

    return action == null ? generic : "Couldn't $action. Please try again.";
  }

  static String? _forCode(String code) {
    switch (code) {
      case 'permission-denied':
        return permission;
      case 'unavailable':
      case 'network-request-failed':
        return connection;
      case 'deadline-exceeded':
        return timeout;
      case 'unauthenticated':
      case 'user-token-expired':
      case 'requires-recent-login':
        return sessionExpired;
      case 'not-found':
        return 'The requested item could not be found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'resource-exhausted':
      case 'too-many-requests':
        return 'Too many requests. Please wait a moment and try again.';
      case 'aborted':
        return 'The operation was interrupted. Please try again.';
      case 'failed-precondition':
        return "This action can't be completed right now. Please try again later.";
      case 'cancelled':
        return 'The operation was cancelled.';
      default:
        return null;
    }
  }
}
