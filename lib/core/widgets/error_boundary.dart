import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../services/logger_service.dart';
import '../theme/app_theme.dart';

class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();

    // Chain onto the handler installed in main.dart (logging, and crash
    // reporting where supported) instead of replacing it.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // Ignore RenderFlex overflow errors in debug mode (they're just visual warnings)
      final errorString = details.exception.toString();
      if (errorString.contains('RenderFlex overflowed') ||
          errorString.contains('A RenderFlex overflowed')) {
        LoggerService.warning(
          'Layout overflow (debug only)',
          error: details.exception,
        );
        return;
      }

      if (previousOnError != null) {
        previousOnError(details);
      } else {
        LoggerService.error(
          'Flutter Error',
          error: details.exception,
          stackTrace: details.stack,
        );
      }

      // Schedule setState for next frame to avoid build conflicts
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _error = details.exception;
              _stackTrace = details.stack;
            });
          }
        });
      }

      widget.onError
          ?.call(details.exception, details.stack ?? StackTrace.empty);
    };
  }

  void _reset() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Separate MaterialApp, so it needs the app theme explicitly; the
      // Builder makes Theme.of below resolve to it.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingXL,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    AppSpacing.gapXL,
                    Text(
                      'Oops! Something went wrong',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapMD,
                    Text(
                      'We encountered an unexpected error. Please try again.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    // Technical details only in debug builds.
                    if (kDebugMode && _error != null) ...[
                      AppSpacing.gapMD,
                      Container(
                        padding: AppSpacing.paddingMD,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error.toString(),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontFamily: 'monospace',
                                  ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    AppSpacing.gapXL,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
