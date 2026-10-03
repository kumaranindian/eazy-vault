import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/models/failure.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../transactions/presentation/providers/financial_refresh.dart';
import '../../data/models/recurring_transaction_model.dart';
import 'recurring_transactions_providers.dart';

part 'recurring_transactions_notifier.freezed.dart';
part 'recurring_transactions_notifier.g.dart';

@freezed
class RecurringTransactionsState with _$RecurringTransactionsState {
  const factory RecurringTransactionsState.initial() = _Initial;
  const factory RecurringTransactionsState.loading() = _Loading;
  const factory RecurringTransactionsState.loaded(List<RecurringTransactionModel> rules) =
      _Loaded;
  const factory RecurringTransactionsState.error(Failure failure) = _Error;
}

@riverpod
class RecurringTransactionsNotifier extends _$RecurringTransactionsNotifier {
  @override
  RecurringTransactionsState build() {
    _loadRules();
    return const RecurringTransactionsState.initial();
  }

  Future<void> _loadRules() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const RecurringTransactionsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return;
    }

    state = const RecurringTransactionsState.loading();

    final repository = ref.read(recurringTransactionsRepositoryProvider);
    final result = await repository.getRecurringTransactions(user.uid);

    if (result.failure != null) {
      state = RecurringTransactionsState.error(result.failure!);
    } else {
      state = RecurringTransactionsState.loaded(result.rules);
    }
  }

  /// Creates [rule], then immediately runs [RecurringTransactionService.catchUp]
  /// so any already-due occurrences (e.g. a past `startDate`) are generated
  /// right away instead of waiting for the next app session's catch-up pass.
  /// Returns how many occurrences were generated so the caller can say so.
  Future<({Failure? failure, int generatedCount})> createRule(
    RecurringTransactionModel rule,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return (
        failure: const Failure.authenticationError('User not authenticated'),
        generatedCount: 0,
      );
    }

    final link = ref.keepAlive();
    try {
      final result = await ref
          .read(recurringTransactionsRepositoryProvider)
          .createRecurringTransaction(user.uid, rule);
      if (result.failure != null) {
        return (failure: result.failure, generatedCount: 0);
      }

      final generatedCount = await ref
          .read(recurringTransactionServiceProvider)
          .catchUp(user.uid, result.rule!);
      if (generatedCount > 0) {
        refreshFinancialData(ref.invalidate);
      }

      await _loadRules();
      return (failure: null, generatedCount: generatedCount);
    } finally {
      link.close();
    }
  }

  Future<Failure?> updateRule(RecurringTransactionModel rule) {
    return _mutate((userId) async {
      final result =
          await ref.read(recurringTransactionsRepositoryProvider).updateRecurringTransaction(
                userId,
                rule,
              );
      return result.failure;
    });
  }

  Future<Failure?> deleteRule(String ruleId) {
    return _mutate((userId) async {
      return ref
          .read(recurringTransactionsRepositoryProvider)
          .deleteRecurringTransaction(userId, ruleId);
    });
  }

  /// Toggles a rule active/paused without touching its schedule.
  Future<Failure?> setActive(RecurringTransactionModel rule, bool isActive) {
    return updateRule(rule.copyWith(isActive: isActive));
  }

  /// Runs a write and reloads the list on success. Returns `null` on success,
  /// otherwise the [Failure]; the list state is left untouched on failure.
  Future<Failure?> _mutate(
    Future<Failure?> Function(String userId) operation,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return const Failure.authenticationError('User not authenticated');
    }

    final link = ref.keepAlive();
    try {
      final failure = await operation(user.uid);
      if (failure != null) return failure;

      await _loadRules();
      return null;
    } finally {
      link.close();
    }
  }

  void refresh() {
    _loadRules();
  }
}
