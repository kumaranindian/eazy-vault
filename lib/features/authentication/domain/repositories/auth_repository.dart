import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/models/failure.dart';
import '../../data/models/user_model.dart';

abstract class AuthRepository {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  
  Future<({UserModel user, Failure? failure})> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  });
  
  Future<({UserModel user, Failure? failure})> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });
  
  Future<({UserModel user, Failure? failure})> signInWithGoogle();
  
  Future<Failure?> signOut();
  
  Future<Failure?> sendPasswordResetEmail(String email);
  
  Future<Failure?> sendEmailVerification();
  
  Future<Failure?> reloadUser();
  
  Future<({UserModel? user, Failure? failure})> getUserData(String userId);
  
  Future<({bool rememberMe, Failure? failure})> getRememberMe();
  
  Future<({String? email, Failure? failure})> getLastEmail();
}
