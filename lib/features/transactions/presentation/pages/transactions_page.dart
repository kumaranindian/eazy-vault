import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/transactions_notifier.dart';
import '../widgets/empty_transactions_state.dart';
import '../widgets/transaction_card.dart';
import '../widgets/transaction_list_header.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Trigger initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsNotifierProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(transactionsNotifierProvider.notifier).loadMore();
    }
  }

  Map<String, List<dynamic>> _groupTransactionsByDate(List transactions) {
    final Map<String, List<dynamic>> grouped = {};
    
    for (final transaction in transactions) {
      final date = transaction.date as DateTime;
      final dateKey = _getDateKey(date);
      
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }
    
    return grouped;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return date.toFormattedDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsState = ref.watch(transactionsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
              context.showInfoSnackBar('Search - Coming Soon');
            },
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filters
              context.showInfoSnackBar('Filters - Coming Soon');
            },
            tooltip: 'Filter',
          ),
        ],
      ),
      body: transactionsState.when(
        initial: () => const LoadingIndicator(),
        loading: () => const LoadingIndicator(),
        error: (failure) => ErrorView(
          message: failure.message,
          onRetry: () => ref.read(transactionsNotifierProvider.notifier).refresh(),
        ),
        loaded: (transactions, hasMore, _) {
          if (transactions.isEmpty) {
            return EmptyTransactionsState(
              onAddTransaction: () => context.push(RouteConstants.addExpense),
            );
          }

          final groupedTransactions = _groupTransactionsByDate(transactions);
          final dateKeys = groupedTransactions.keys.toList();

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(transactionsNotifierProvider.notifier).refresh();
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: AppSpacing.paddingMD,
              itemCount: dateKeys.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == dateKeys.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final dateKey = dateKeys[index];
                final dayTransactions = groupedTransactions[dateKey]!;
                final dayTotal = dayTransactions.fold<double>(
                  0,
                  (sum, t) => sum + (t.isIncome ? t.amount : -t.amount),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0) AppSpacing.gapMD,
                    TransactionListHeader(
                      date: dateKey,
                      total: dayTotal.abs(),
                      isIncome: dayTotal >= 0,
                    ),
                    AppSpacing.gapSM,
                    ...dayTransactions.map((transaction) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TransactionCard(
                          transaction: transaction,
                          onTap: () => context.push(
                            RouteConstants.transactionDetail
                                .replaceAll(':id', transaction.id),
                          ),
                          onDelete: () async {
                            final success = await ref
                                .read(transactionsNotifierProvider.notifier)
                                .deleteTransaction(
                                  transaction.id,
                                  transaction,
                                );

                            if (success && context.mounted) {
                              context.showSuccessSnackBar(
                                'Transaction deleted successfully',
                              );
                            } else if (context.mounted) {
                              final state = ref.read(transactionsNotifierProvider);
                              state.whenOrNull(
                                error: (failure) =>
                                    context.showErrorSnackBar(failure.message),
                              );
                            }
                          },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          );
        },
        loadingMore: (transactions, hasMore, _) {
          if (transactions.isEmpty) {
            return EmptyTransactionsState(
              onAddTransaction: () => context.push(RouteConstants.addExpense),
            );
          }

          final groupedTransactions = _groupTransactionsByDate(transactions);
          final dateKeys = groupedTransactions.keys.toList();

          return ListView.builder(
            controller: _scrollController,
            padding: AppSpacing.paddingMD,
            itemCount: dateKeys.length + 1,
            itemBuilder: (context, index) {
              if (index == dateKeys.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final dateKey = dateKeys[index];
              final dayTransactions = groupedTransactions[dateKey]!;
              final dayTotal = dayTransactions.fold<double>(
                0,
                (sum, t) => sum + (t.isIncome ? t.amount : -t.amount),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) AppSpacing.gapMD,
                  TransactionListHeader(
                    date: dateKey,
                    total: dayTotal.abs(),
                    isIncome: dayTotal >= 0,
                  ),
                  AppSpacing.gapSM,
                  ...dayTransactions.map((transaction) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransactionCard(
                        transaction: transaction,
                        onTap: () => context.push(
                          RouteConstants.transactionDetail
                              .replaceAll(':id', transaction.id),
                        ),
                        onDelete: () async {
                          final success = await ref
                              .read(transactionsNotifierProvider.notifier)
                              .deleteTransaction(
                                transaction.id,
                                transaction,
                              );

                          if (success && context.mounted) {
                            context.showSuccessSnackBar(
                              'Transaction deleted successfully',
                            );
                          }
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteConstants.addExpense),
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }
}
