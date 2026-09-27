import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) {
  return FirebaseAuth.instance;
}

@Riverpod(keepAlive: true)
FirebaseFirestore firebaseFirestore(FirebaseFirestoreRef ref) {
  return FirebaseFirestore.instance;
}

@Riverpod(keepAlive: true)
GoogleSignIn googleSignIn(GoogleSignInRef ref) {
  return GoogleSignIn(
    scopes: ['email', 'profile'],
  );
}

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(SharedPreferencesRef ref) async {
  return await SharedPreferences.getInstance();
}

@Riverpod(keepAlive: true)
AuthRemoteDataSource authRemoteDataSource(AuthRemoteDataSourceRef ref) {
  return AuthRemoteDataSourceImpl(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  );
}

@Riverpod(keepAlive: true)
Future<AuthLocalDataSource> authLocalDataSource(AuthLocalDataSourceRef ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return AuthLocalDataSourceImpl(sharedPreferences: prefs);
}

@Riverpod(keepAlive: true)
Future<AuthRepository> authRepository(AuthRepositoryRef ref) async {
  final localDataSource = await ref.watch(authLocalDataSourceProvider.future);
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: localDataSource,
  );
}

@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
}

@Riverpod(keepAlive: true)
User? currentUser(CurrentUserRef ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.value;
}
