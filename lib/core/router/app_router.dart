import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/accounts/presentation/pages/account_detail_page.dart';
import '../../features/accounts/presentation/pages/accounts_page.dart';
import '../../features/accounts/presentation/pages/add_edit_account_page.dart';
import '../../features/authentication/presentation/pages/forgot_password_page.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/register_page.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/categories/presentation/pages/add_edit_category_page.dart';
import '../../features/categories/presentation/pages/categories_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/transactions/domain/enums/transaction_type.dart';
import '../../features/transactions/presentation/pages/add_edit_transaction_page.dart';
import '../../features/transactions/presentation/pages/transaction_detail_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../constants/app_constants.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/navigation/app_scaffold.dart';
import '../widgets/splash_screen.dart';

part 'app_router.g.dart';

/// Builds the router once. Auth changes re-run [GoRouter.redirect] through
/// `refreshListenable` instead of recreating the router, so the current
/// location (and deep links) survive sign-in, sign-out and page refreshes.
@Riverpod(keepAlive: true)
GoRouter appRouter(AppRouterRef ref) {
  final authState = ValueNotifier<AsyncValue<User?>>(
    ref.read(authStateChangesProvider),
  );
  ref
    ..listen(authStateChangesProvider, (_, next) => authState.value = next)
    ..onDispose(authState.dispose);

  final router = GoRouter(
    initialLocation: RouteConstants.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: authState,
    redirect: (context, state) {
      final auth = authState.value;
      final location = state.matchedLocation;
      final isSplash = location == RouteConstants.splash;
      final isAuthRoute = location == RouteConstants.login ||
          location == RouteConstants.register ||
          location == RouteConstants.forgotPassword;

      // Location the user originally asked for, carried through splash/login.
      final from = _safeFrom(state.uri.queryParameters['from']);

      if (auth.isLoading && !auth.hasValue) {
        if (isSplash) return null;
        return _withFrom(RouteConstants.splash, state.uri.toString());
      }

      final isAuthenticated = auth.valueOrNull != null;

      if (!isAuthenticated) {
        if (isAuthRoute) return null;
        return _withFrom(
          RouteConstants.login,
          isSplash ? from : state.uri.toString(),
        );
      }

      if (isSplash || isAuthRoute) {
        return from ?? RouteConstants.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteConstants.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteConstants.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteConstants.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RouteConstants.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: RouteConstants.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: RouteConstants.accounts,
            builder: (context, state) => const AccountsPage(),
          ),
          GoRoute(
            path: RouteConstants.categories,
            builder: (context, state) => const CategoriesPage(),
          ),
          GoRoute(
            path: RouteConstants.transactions,
            builder: (context, state) => const TransactionsPage(),
          ),
        ],
      ),
      GoRoute(
        path: RouteConstants.addAccount,
        builder: (context, state) => const AddEditAccountPage(),
      ),
      GoRoute(
        path: RouteConstants.accountDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AccountDetailPage(accountId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.editAccount,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditAccountPage(accountId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.addCategory,
        builder: (context, state) => const AddEditCategoryPage(),
      ),
      GoRoute(
        path: RouteConstants.editCategory,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditCategoryPage(categoryId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.addIncome,
        builder: (context, state) => const AddEditTransactionPage(
          initialType: TransactionType.income,
        ),
      ),
      GoRoute(
        path: RouteConstants.addExpense,
        builder: (context, state) => const AddEditTransactionPage(
          initialType: TransactionType.expense,
        ),
      ),
      GoRoute(
        path: RouteConstants.transactionDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TransactionDetailPage(transactionId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.editTransaction,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditTransactionPage(transactionId: id);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
}

/// Only in-app absolute paths are accepted as a return location.
String? _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.parse(from).path;
  if (path == RouteConstants.splash ||
      path == RouteConstants.login ||
      path == RouteConstants.register ||
      path == RouteConstants.forgotPassword) {
    return null;
  }
  return from;
}

String _withFrom(String target, String? from) {
  final safe = _safeFrom(from);
  if (safe == null) return target;
  return Uri(path: target, queryParameters: {'from': safe}).toString();
}
