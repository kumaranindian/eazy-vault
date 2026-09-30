import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/extensions/transaction_extensions.dart';
import '../providers/transactions_notifier.dart';
import '../widgets/empty_transactions_state.dart';
import '../widgets/transaction_card.dart';
import '../widgets/transaction_list_header.dart';
import '../widgets/transactions_modal.dart';

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

  Map<String, List<TransactionModel>> _groupTransactionsByDate(
    List<TransactionModel> transactions,
  ) {
    final grouped = <String, List<TransactionModel>>{};

    for (final transaction in transactions) {
      final date = transaction.date;
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

  Future<void> _showSearchDialog() async {
    final notifier = ref.read(transactionsNotifierProvider.notifier);
    final controller = TextEditingController(text: notifier.searchQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search transactions'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Description, vendor or amount',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query != null && mounted) {
      notifier.searchTransactions(query);
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
            onPressed: _showSearchDialog,
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            // The transactions modal holds the filter controls and applies
            // them to the same list this page shows.
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => const TransactionsModal(),
            ),
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
                  (sum, t) => sum + t.cashFlow,
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
                            final failure = await ref
                                .read(transactionsNotifierProvider.notifier)
                                .deleteTransaction(
                                  transaction.id,
                                  transaction,
                                );

                            if (failure == null && context.mounted) {
                              context.showSuccessSnackBar(
                                'Transaction deleted successfully',
                              );
                            } else if (context.mounted) {
                              context.showErrorSnackBar(failure?.message);
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
                (sum, t) => sum + t.cashFlow,
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
                          final failure = await ref
                              .read(transactionsNotifierProvider.notifier)
                              .deleteTransaction(
                                transaction.id,
                                transaction,
                              );

                          if (failure == null && context.mounted) {
                            context.showSuccessSnackBar(
                              'Transaction deleted successfully',
                            );
                          } else if (context.mounted) {
                            context.showErrorSnackBar(failure?.message);
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
