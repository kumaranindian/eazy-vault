import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
import 'financial_refresh.dart';
import 'transactions_providers.dart';

part 'transactions_notifier.freezed.dart';
part 'transactions_notifier.g.dart';

@freezed
class TransactionsState with _$TransactionsState {
  const factory TransactionsState.initial() = _Initial;
  const factory TransactionsState.loading() = _Loading;
  const factory TransactionsState.loaded({
    required List<TransactionModel> transactions,
    required bool hasMore,
    DocumentSnapshot? lastDocument,
  }) = _Loaded;
  const factory TransactionsState.loadingMore({
    required List<TransactionModel> transactions,
    required bool hasMore,
    DocumentSnapshot? lastDocument,
  }) = _LoadingMore;
  const factory TransactionsState.error(Failure failure) = _Error;
}

@freezed
class TransactionFilters with _$TransactionFilters {
  const factory TransactionFilters({
    TransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) = _TransactionFilters;
}

@riverpod
class TransactionsNotifier extends _$TransactionsNotifier {
  TransactionFilters _filters = const TransactionFilters();
  DocumentSnapshot? _lastDocument;

  @override
  TransactionsState build() {
    _loadTransactions();
    return const TransactionsState.initial();
  }

  Future<void> _loadTransactions({bool loadMore = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const TransactionsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return;
    }

    if (!loadMore) {
      state = const TransactionsState.loading();
      _lastDocument = null;
    } else {
      state.whenOrNull(
        loaded: (transactions, hasMore, lastDoc) {
          state = TransactionsState.loadingMore(
            transactions: transactions,
            hasMore: hasMore,
            lastDocument: lastDoc,
          );
        },
      );
    }

    final repository = ref.read(transactionsRepositoryProvider);
    final result = await repository.getTransactions(
      user.uid,
      type: _filters.type,
      accountId: _filters.accountId,
      categoryId: _filters.categoryId,
      startDate: _filters.startDate,
      endDate: _filters.endDate,
      lastDocument: loadMore ? _lastDocument : null,
    );

    if (result.failure != null) {
      state = TransactionsState.error(result.failure!);
      return;
    }

    final lastDoc = result.lastDocument;
    final hasMore = result.transactions.length >= 20;
    // Firestore has no text search: the query is applied to each loaded page.
    final newTransactions = _applySearch(result.transactions);

    if (loadMore) {
      state.whenOrNull(
        loadingMore: (existingTransactions, _, __) {
          state = TransactionsState.loaded(
            transactions: [...existingTransactions, ...newTransactions],
            hasMore: hasMore,
            lastDocument: lastDoc ?? _lastDocument,
          );
        },
      );
    } else {
      state = TransactionsState.loaded(
        transactions: newTransactions,
        hasMore: hasMore,
        lastDocument: lastDoc,
      );
    }

    if (lastDoc != null) {
      _lastDocument = lastDoc;
    }
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is _Loaded && currentState.hasMore) {
      await _loadTransactions(loadMore: true);
    }
  }

  /// Returns `null` on success, otherwise the [Failure]. The list state is
  /// left untouched on failure so the UI can show the error in place.
  Future<Failure?> createTransaction(TransactionModel transaction) {
    return _mutate((userId) async {
      final result = await ref
          .read(transactionsRepositoryProvider)
          .createTransaction(userId, transaction);
      return result.failure;
    });
  }

  Future<Failure?> updateTransaction(TransactionModel transaction) {
    return _mutate((userId) async {
      final result = await ref
          .read(transactionsRepositoryProvider)
          .updateTransaction(userId, transaction);
      return result.failure;
    });
  }

  Future<Failure?> deleteTransaction(
    String transactionId,
    TransactionModel transaction,
  ) {
    return _mutate((userId) {
      return ref
          .read(transactionsRepositoryProvider)
          .deleteTransaction(userId, transactionId, transaction);
    });
  }

  Future<Failure?> _mutate(
    Future<Failure?> Function(String userId) operation,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return const Failure.authenticationError('User not authenticated');
    }

    // Callers often use `ref.read` from dialogs; keep this auto-dispose
    // notifier alive until the write and the refresh have finished.
    final link = ref.keepAlive();
    try {
      final failure = await operation(user.uid);
      if (failure != null) return failure;

      refreshFinancialData(ref.invalidate);
      await refresh();
      return null;
    } finally {
      link.close();
    }
  }

  void filterByType(TransactionType? type) {
    _filters = _filters.copyWith(type: type);
    refresh();
  }

  void filterByAccount(String? accountId) {
    _filters = _filters.copyWith(accountId: accountId);
    refresh();
  }

  void filterByCategory(String? categoryId) {
    _filters = _filters.copyWith(categoryId: categoryId);
    refresh();
  }

  void filterByDateRange(DateTime? startDate, DateTime? endDate) {
    _filters = _filters.copyWith(startDate: startDate, endDate: endDate);
    refresh();
  }

  /// Current search text (empty when not searching).
  String get searchQuery => _filters.searchQuery ?? '';

  void searchTransactions(String query) {
    final trimmed = query.trim();
    _filters = _filters.copyWith(searchQuery: trimmed.isEmpty ? null : trimmed);
    refresh();
  }

  List<TransactionModel> _applySearch(List<TransactionModel> transactions) {
    final query = _filters.searchQuery?.toLowerCase();
    if (query == null || query.isEmpty) return transactions;
    return transactions.where((t) {
      return (t.description?.toLowerCase().contains(query) ?? false) ||
          (t.vendor?.toLowerCase().contains(query) ?? false) ||
          t.amount.toStringAsFixed(2).contains(query) ||
          t.type.displayName.toLowerCase().contains(query);
    }).toList();
  }

  void applyFilters({
    TransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    _filters = TransactionFilters(
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
    refresh();
  }

  void clearFilters() {
    _filters = const TransactionFilters();
    refresh();
  }

  Future<void> refresh() async {
    _lastDocument = null;
    await _loadTransactions();
  }
}

@riverpod
Future<TransactionModel?> transaction(
  TransactionRef ref,
  String transactionId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    LoggerService.warning('User not authenticated');
    return null;
  }

  final repository = ref.watch(transactionsRepositoryProvider);
  final result = await repository.getTransaction(user.uid, transactionId);

  if (result.failure != null) {
    LoggerService.error('Failed to fetch transaction', error: result.failure);
    return null;
  }

  return result.transaction;
}

@riverpod
Stream<List<TransactionModel>> recentTransactions(
  RecentTransactionsRef ref, {
  int limit = 10,
}) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.watchTransactions(user.uid, limit: limit);
}
