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
        // firebase_crashlytics has no web implementation.
        if (!kIsWeb) {
          await _initializeCrashlytics();
        }
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
      // Chain onto the existing handlers so logging keeps working.
      final previousFlutterOnError = FlutterError.onError;
      FlutterError.onError = (errorDetails) {
        previousFlutterOnError?.call(errorDetails);
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      final previousPlatformOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        previousPlatformOnError?.call(error, stack);
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
