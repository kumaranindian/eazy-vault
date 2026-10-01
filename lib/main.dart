import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/firebase_service.dart';
import 'core/services/logger_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/error_boundary.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Install logging handlers first; FirebaseService and ErrorBoundary
      // chain onto these instead of replacing them.
      FlutterError.onError = (details) {
        LoggerService.error(
          'Flutter Error',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        LoggerService.error('Platform Error', error: error, stackTrace: stack);
        return true;
      };

      await FirebaseService.initialize();

      LoggerService.info('EazyVault application started');

      runApp(
        const ProviderScope(
          child: ErrorBoundary(
            child: EazyVaultApp(),
          ),
        ),
      );
    },
    (error, stack) {
      LoggerService.error('Uncaught Error', error: error, stackTrace: stack);
    },
  );
}

class EazyVaultApp extends ConsumerWidget {
  const EazyVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
