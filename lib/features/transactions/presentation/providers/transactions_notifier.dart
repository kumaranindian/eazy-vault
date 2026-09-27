import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/enums/transaction_type.dart';
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

    final newTransactions = result.transactions;
    final lastDoc = result.lastDocument;
    final hasMore = newTransactions.length >= 20;

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

  Future<bool> createTransaction(TransactionModel transaction) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const TransactionsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return false;
    }

    final repository = ref.read(transactionsRepositoryProvider);
    final result = await repository.createTransaction(user.uid, transaction);

    if (result.failure != null) {
      state = TransactionsState.error(result.failure!);
      return false;
    }

    await refresh();
    return true;
  }

  Future<bool> updateTransaction(
    TransactionModel transaction,
    TransactionModel? oldTransaction,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const TransactionsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return false;
    }

    final repository = ref.read(transactionsRepositoryProvider);
    final result = await repository.updateTransaction(
      user.uid,
      transaction,
      oldTransaction,
    );

    if (result.failure != null) {
      state = TransactionsState.error(result.failure!);
      return false;
    }

    await refresh();
    return true;
  }

  Future<bool> deleteTransaction(
    String transactionId,
    TransactionModel transaction,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const TransactionsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return false;
    }

    final repository = ref.read(transactionsRepositoryProvider);
    final failure = await repository.deleteTransaction(
      user.uid,
      transactionId,
      transaction,
    );

    if (failure != null) {
      state = TransactionsState.error(failure);
      return false;
    }

    await refresh();
    return true;
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

  void searchTransactions(String query) {
    _filters = _filters.copyWith(searchQuery: query);
    refresh();
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
