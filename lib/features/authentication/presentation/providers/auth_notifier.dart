import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/user_model.dart';
import 'auth_providers.dart';

part 'auth_notifier.freezed.dart';
part 'auth_notifier.g.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(UserModel user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.error(Failure failure) = _Error;
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    _listenToAuthChanges();
    return const AuthState.initial();
  }

  void _listenToAuthChanges() {
    ref.listen(authStateChangesProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            _loadUserData(user.uid);
          } else {
            state = const AuthState.unauthenticated();
          }
        },
        loading: () => state = const AuthState.loading(),
        error: (error, stack) {
          LoggerService.error('Auth state error', error: error, stackTrace: stack);
          state = AuthState.error(Failure.unknownError(error.toString()));
        },
      );
    });
  }

  Future<void> _loadUserData(String userId) async {
    final repository = await ref.read(authRepositoryProvider.future);
    final result = await repository.getUserData(userId);

    if (result.failure != null) {
      state = AuthState.error(result.failure!);
      return;
    }

    if (result.user != null) {
      state = AuthState.authenticated(result.user!);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    state = const AuthState.loading();

    final repository = await ref.read(authRepositoryProvider.future);
    final result = await repository.signInWithEmailAndPassword(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );

    if (result.failure != null) {
      state = AuthState.error(result.failure!);
      return false;
    }

    state = AuthState.authenticated(result.user);
    return true;
  }

  Future<bool> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthState.loading();

    final repository = await ref.read(authRepositoryProvider.future);
    final result = await repository.signUpWithEmailAndPassword(
      email: email,
      password: password,
      displayName: displayName,
    );

    if (result.failure != null) {
      state = AuthState.error(result.failure!);
      return false;
    }

    state = AuthState.authenticated(result.user);
    return true;
  }

  Future<bool> signInWithGoogle() async {
    state = const AuthState.loading();

    final repository = await ref.read(authRepositoryProvider.future);
    final result = await repository.signInWithGoogle();

    if (result.failure != null) {
      state = AuthState.error(result.failure!);
      return false;
    }

    state = AuthState.authenticated(result.user);
    return true;
  }

  Future<bool> signOut() async {
    state = const AuthState.loading();

    final repository = await ref.read(authRepositoryProvider.future);
    final failure = await repository.signOut();

    if (failure != null) {
      state = AuthState.error(failure);
      return false;
    }

    state = const AuthState.unauthenticated();
    return true;
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    final repository = await ref.read(authRepositoryProvider.future);
    final failure = await repository.sendPasswordResetEmail(email);

    if (failure != null) {
      state = AuthState.error(failure);
      return false;
    }

    return true;
  }

  Future<bool> sendEmailVerification() async {
    final repository = await ref.read(authRepositoryProvider.future);
    final failure = await repository.sendEmailVerification();

    if (failure != null) {
      state = AuthState.error(failure);
      return false;
    }

    return true;
  }

  Future<void> reloadUser() async {
    final repository = await ref.read(authRepositoryProvider.future);
    await repository.reloadUser();
  }

  /// Updates the signed-in user's display name. Unlike the other methods
  /// here, this doesn't set `state = loading` first — the profile page
  /// tracks its own saving state (same pattern as other edit forms), so the
  /// rest of the app relying on `AuthState.authenticated` isn't disrupted
  /// mid-save.
  Future<Failure?> updateDisplayName(String userId, String displayName) async {
    final repository = await ref.read(authRepositoryProvider.future);
    final result = await repository.updateDisplayName(userId, displayName);
    if (result.failure != null) return result.failure;
    state = AuthState.authenticated(result.user);
    return null;
  }
}

@riverpod
Future<bool> rememberMe(RememberMeRef ref) async {
  final repository = await ref.watch(authRepositoryProvider.future);
  final result = await repository.getRememberMe();
  return result.rememberMe;
}

@riverpod
Future<String?> lastEmail(LastEmailRef ref) async {
  final repository = await ref.watch(authRepositoryProvider.future);
  final result = await repository.getLastEmail();
  return result.email;
}
