import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../models/user_model.dart';
import '../../../../core/utils/error_messages.dart';

abstract class AuthRemoteDataSource {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });
  
  Future<UserModel> signInWithGoogle();
  
  Future<void> signOut();
  
  Future<void> sendPasswordResetEmail(String email);
  
  Future<void> sendEmailVerification();
  
  Future<void> reloadUser();
  
  Future<UserModel?> getUserData(String userId);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _googleSignIn = googleSignIn;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      LoggerService.info('Attempting email/password sign in for: $email');
      
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw const AuthenticationException('Sign in failed');
      }

      final userData = await getUserData(userCredential.user!.uid);
      
      if (userData != null) {
        return userData;
      }

      return await _createUserDocument(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Firebase auth error', error: e);
      throw AuthenticationException(_getAuthErrorMessage(e.code), e.code);
    } catch (e, stackTrace) {
      LoggerService.error('Sign in error', error: e, stackTrace: stackTrace);
      throw AuthenticationException(ErrorMessages.from(e, action: 'sign in'));
    }
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      LoggerService.info('Attempting email/password sign up for: $email');
      
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw const AuthenticationException('Sign up failed');
      }

      if (displayName != null) {
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
      }

      await userCredential.user!.sendEmailVerification();

      return await _createUserDocument(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Firebase auth error', error: e);
      throw AuthenticationException(_getAuthErrorMessage(e.code), e.code);
    } catch (e, stackTrace) {
      LoggerService.error('Sign up error', error: e, stackTrace: stackTrace);
      throw AuthenticationException(ErrorMessages.from(e, action: 'sign up'));
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      LoggerService.info('Attempting Google sign in');
      
      final googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw const AuthenticationException('Google sign in cancelled');
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw const AuthenticationException('Google sign in failed');
      }

      final userData = await getUserData(userCredential.user!.uid);
      
      if (userData != null) {
        return userData;
      }

      return await _createUserDocument(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Firebase auth error', error: e);
      throw AuthenticationException(_getAuthErrorMessage(e.code), e.code);
    } catch (e, stackTrace) {
      LoggerService.error('Google sign in error', error: e, stackTrace: stackTrace);
      throw AuthenticationException(ErrorMessages.from(e, action: 'sign in with Google'));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      LoggerService.info('Signing out user');
      
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
      
      LoggerService.info('User signed out successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Sign out error', error: e, stackTrace: stackTrace);
      throw AuthenticationException(ErrorMessages.from(e, action: 'sign out'));
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      LoggerService.info('Sending password reset email to: $email');
      
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      
      LoggerService.info('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Firebase auth error', error: e);
      throw AuthenticationException(_getAuthErrorMessage(e.code), e.code);
    } catch (e, stackTrace) {
      LoggerService.error('Password reset error', error: e, stackTrace: stackTrace);
      throw AuthenticationException(ErrorMessages.from(e, action: 'send password reset email'));
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      
      if (user == null) {
        throw const AuthenticationException('No user signed in');
      }

      if (user.emailVerified) {
        LoggerService.info('Email already verified');
        return;
      }

      LoggerService.info('Sending email verification');
      
      await user.sendEmailVerification();
      
      LoggerService.info('Email verification sent');
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Firebase auth error', error: e);
      throw AuthenticationException(_getAuthErrorMessage(e.code), e.code);
    } catch (e, stackTrace) {
      LoggerService.error('Email verification error', error: e, stackTrace: stackTrace);
      throw AuthenticationException(ErrorMessages.from(e, action: 'send email verification'));
    }
  }

  @override
  Future<void> reloadUser() async {
    try {
      final user = currentUser;
      
      if (user == null) {
        throw const AuthenticationException('No user signed in');
      }

      await user.reload();
    } catch (e, stackTrace) {
      LoggerService.error('Reload user error', error: e, stackTrace: stackTrace);
      throw AuthenticationException(ErrorMessages.from(e, action: 'reload user'));
    }
  }

  @override
  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        return null;
      }

      return UserModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      LoggerService.error('Get user data error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'load your profile'));
    }
  }

  Future<UserModel> _createUserDocument(User user) async {
    try {
      final now = DateTime.now();
      
      final userModel = UserModel(
        id: user.uid,
        email: user.email!,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        createdAt: now,
        updatedAt: now,
        emailVerified: user.emailVerified,
      );

      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toFirestore());
        LoggerService.info('User document created: ${user.uid}');
      } catch (e, stackTrace) {
        // The Firebase Auth account already exists and is signed in; the
        // profile document is not required for the app to work, so don't fail
        // sign-up/sign-in because of it. It is retried on the next sign-in.
        LoggerService.error('Create user document error', error: e, stackTrace: stackTrace);
      }

      return userModel;
    } catch (e, stackTrace) {
      LoggerService.error('Create user document error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'save your profile'));
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in was cancelled';
      case 'popup-blocked':
        return 'The sign-in popup was blocked by your browser. Please allow popups and try again';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}
