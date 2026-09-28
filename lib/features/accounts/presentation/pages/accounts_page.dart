import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/accounts_notifier.dart';
import '../widgets/recalculate_balances_action.dart';
import '../widgets/account_card.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsState = ref.watch(accountsNotifierProvider);
    final totalBalance = ref.watch(totalBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(accountsNotifierProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
          const SyncBalancesButton(),
        ],
      ),
      body: accountsState.when(
        initial: () => const LoadingIndicator(),
        loading: () => const LoadingIndicator(),
        error: (failure) => ErrorView(
          message: failure.message,
          onRetry: () => ref.read(accountsNotifierProvider.notifier).refresh(),
        ),
        loaded: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              title: 'No Accounts Yet',
              message: 'Create your first account to start tracking your finances',
              iconData: Icons.account_balance_wallet_outlined,
              action: () => context.push(RouteConstants.addAccount),
              actionLabel: 'Add Account',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
              
              return RefreshIndicator(
                onRefresh: () async {
                  ref.read(accountsNotifierProvider.notifier).refresh();
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 16 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Total Balance',
                                        style: context.textTheme.titleMedium?.copyWith(
                                          color: context.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'}',
                                        style: context.textTheme.labelSmall,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isMobile ? 8 : 12),
                                Text(
                                  totalBalance.toCurrency(),
                                  style: (isMobile 
                                      ? context.textTheme.headlineSmall 
                                      : context.textTheme.headlineMedium)?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: totalBalance >= 0
                                        ? context.colorScheme.primary
                                        : context.colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Current Balance',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                                SizedBox(height: isMobile ? 12 : 16),
                                const Divider(),
                                SizedBox(height: isMobile ? 8 : 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.account_balance,
                                            size: 16,
                                            color: context.colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Opening Balance',
                                              style: context.textTheme.bodyMedium?.copyWith(
                                                color: context.colorScheme.onSurface.withOpacity(0.6),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      accounts.fold<double>(
                                        0,
                                        (sum, account) => sum + account.openingBalance,
                                      ).toCurrency(),
                                      style: context.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: context.colorScheme.tertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: 0,
                      ),
                      sliver: isTablet || !isMobile
                          ? SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isTablet ? 2 : 3,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 2.5,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final account = accounts[index];
                                  return AccountCard(
                                    account: account,
                                    onTap: () => context.push(
                                      RouteConstants.accountDetail.replaceAll(':id', account.id),
                                    ),
                                  );
                                },
                                childCount: accounts.length,
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final account = accounts[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index < accounts.length - 1 ? 12 : 0,
                                    ),
                                    child: AccountCard(
                                      account: account,
                                      onTap: () => context.push(
                                        RouteConstants.accountDetail.replaceAll(':id', account.id),
                                      ),
                                    ),
                                  );
                                },
                                childCount: accounts.length,
                              ),
                            ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteConstants.addAccount),
        child: const Icon(Icons.add),
      ),
    );
  }
}
