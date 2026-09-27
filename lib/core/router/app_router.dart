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
import '../widgets/splash_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: RouteConstants.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthLoading = authState.isLoading;
      final isAuthenticated = authState.value != null;
      
      final isLoginRoute = state.matchedLocation == RouteConstants.login;
      final isRegisterRoute = state.matchedLocation == RouteConstants.register;
      final isForgotPasswordRoute = state.matchedLocation == RouteConstants.forgotPassword;
      final isAuthRoute = isLoginRoute || isRegisterRoute || isForgotPasswordRoute;

      if (isAuthLoading) {
        return RouteConstants.splash;
      }

      if (!isAuthenticated && !isAuthRoute) {
        return RouteConstants.login;
      }

      if (isAuthenticated && isAuthRoute) {
        return RouteConstants.dashboard;
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
      GoRoute(
        path: RouteConstants.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: RouteConstants.accounts,
        builder: (context, state) => const AccountsPage(),
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
        path: RouteConstants.categories,
        builder: (context, state) => const CategoriesPage(),
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
        path: RouteConstants.transactions,
        builder: (context, state) => const TransactionsPage(),
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
}
