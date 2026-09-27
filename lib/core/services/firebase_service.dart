import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'logger_service.dart';

class FirebaseService {
  const FirebaseService._();

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      LoggerService.info('Firebase initialized successfully');

      if (!kDebugMode) {
        await _initializeCrashlytics();
        await _initializeAnalytics();
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        'Failed to initialize Firebase',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> _initializeCrashlytics() async {
    try {
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      LoggerService.info('Firebase Crashlytics initialized');
    } catch (e) {
      LoggerService.error('Failed to initialize Crashlytics', error: e);
    }
  }

  static Future<void> _initializeAnalytics() async {
    try {
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(true);
      LoggerService.info('Firebase Analytics initialized');
    } catch (e) {
      LoggerService.error('Failed to initialize Analytics', error: e);
    }
  }
}
