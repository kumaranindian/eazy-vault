import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';
import '../../../../core/utils/error_messages.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  User? get currentUser => _remoteDataSource.currentUser;

  @override
  Stream<User?> get authStateChanges => _remoteDataSource.authStateChanges;

  @override
  Future<({UserModel user, Failure? failure})> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final user = await _remoteDataSource.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (rememberMe) {
        await _localDataSource.setRememberMe(true);
        await _localDataSource.setLastEmail(email);
      } else {
        await _localDataSource.clearAuthData();
      }

      return (user: user, failure: null);
    } on AuthenticationException catch (e) {
      LoggerService.error('Authentication error', error: e);
      return (user: _emptyUser(), failure: Failure.authenticationError(e.message));
    } on NetworkException catch (e) {
      LoggerService.error('Network error', error: e);
      return (user: _emptyUser(), failure: Failure.networkError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (user: _emptyUser(), failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (user: _emptyUser(), failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({UserModel user, Failure? failure})> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final user = await _remoteDataSource.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      return (user: user, failure: null);
    } on AuthenticationException catch (e) {
      LoggerService.error('Authentication error', error: e);
      return (user: _emptyUser(), failure: Failure.authenticationError(e.message));
    } on NetworkException catch (e) {
      LoggerService.error('Network error', error: e);
      return (user: _emptyUser(), failure: Failure.networkError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (user: _emptyUser(), failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (user: _emptyUser(), failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({UserModel user, Failure? failure})> signInWithGoogle() async {
    try {
      final user = await _remoteDataSource.signInWithGoogle();
      return (user: user, failure: null);
    } on AuthenticationException catch (e) {
      LoggerService.error('Authentication error', error: e);
      return (user: _emptyUser(), failure: Failure.authenticationError(e.message));
    } on NetworkException catch (e) {
      LoggerService.error('Network error', error: e);
      return (user: _emptyUser(), failure: Failure.networkError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (user: _emptyUser(), failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (user: _emptyUser(), failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<Failure?> signOut() async {
    try {
      await _remoteDataSource.signOut();
      await _localDataSource.clearAuthData();
      return null;
    } on AuthenticationException catch (e) {
      LoggerService.error('Authentication error', error: e);
      return Failure.authenticationError(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return Failure.unknownError(ErrorMessages.from(e));
    }
  }

  @override
  Future<Failure?> sendPasswordResetEmail(String email) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email);
      return null;
    } on AuthenticationException catch (e) {
      LoggerService.error('Authentication error', error: e);
      return Failure.authenticationError(e.message);
    } on NetworkException catch (e) {
      LoggerService.error('Network error', error: e);
      return Failure.networkError(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return Failure.unknownError(ErrorMessages.from(e));
    }
  }

  @override
  Future<Failure?> sendEmailVerification() async {
    try {
      await _remoteDataSource.sendEmailVerification();
      return null;
    } on AuthenticationException catch (e) {
      LoggerService.error('Authentication error', error: e);
      return Failure.authenticationError(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return Failure.unknownError(ErrorMessages.from(e));
    }
  }

  @override
  Future<Failure?> reloadUser() async {
    try {
      await _remoteDataSource.reloadUser();
      return null;
    } on AuthenticationException catch (e) {
      LoggerService.error('Authentication error', error: e);
      return Failure.authenticationError(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return Failure.unknownError(ErrorMessages.from(e));
    }
  }

  @override
  Future<({UserModel? user, Failure? failure})> getUserData(String userId) async {
    try {
      final user = await _remoteDataSource.getUserData(userId);
      return (user: user, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (user: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (user: null, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({bool rememberMe, Failure? failure})> getRememberMe() async {
    try {
      final rememberMe = await _localDataSource.getRememberMe();
      return (rememberMe: rememberMe, failure: null);
    } on CacheException catch (e) {
      LoggerService.error('Cache error', error: e);
      return (rememberMe: false, failure: Failure.unknownError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (rememberMe: false, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({String? email, Failure? failure})> getLastEmail() async {
    try {
      final email = await _localDataSource.getLastEmail();
      return (email: email, failure: null);
    } on CacheException catch (e) {
      LoggerService.error('Cache error', error: e);
      return (email: null, failure: Failure.unknownError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (email: null, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  UserModel _emptyUser() {
    return UserModel(
      id: '',
      email: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
