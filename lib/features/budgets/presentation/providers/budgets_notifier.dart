import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/models/failure.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/budget_model.dart';
import 'budgets_providers.dart';

part 'budgets_notifier.freezed.dart';
part 'budgets_notifier.g.dart';

@freezed
class BudgetsState with _$BudgetsState {
  const factory BudgetsState.initial() = _Initial;
  const factory BudgetsState.loading() = _Loading;
  const factory BudgetsState.loaded(List<BudgetModel> budgets) = _Loaded;
  const factory BudgetsState.error(Failure failure) = _Error;
}

@riverpod
class BudgetsNotifier extends _$BudgetsNotifier {
  @override
  BudgetsState build() {
    _loadBudgets();
    return const BudgetsState.initial();
  }

  Future<void> _loadBudgets() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const BudgetsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return;
    }

    state = const BudgetsState.loading();

    final repository = ref.read(budgetsRepositoryProvider);
    final result = await repository.getBudgets(user.uid);

    if (result.failure != null) {
      state = BudgetsState.error(result.failure!);
    } else {
      state = BudgetsState.loaded(result.budgets);
    }
  }

  Future<Failure?> createBudget(BudgetModel budget) {
    return _mutate((userId) async {
      final result = await ref.read(budgetsRepositoryProvider).createBudget(userId, budget);
      return result.failure;
    });
  }

  Future<Failure?> updateBudget(BudgetModel budget) {
    return _mutate((userId) async {
      final result = await ref.read(budgetsRepositoryProvider).updateBudget(userId, budget);
      return result.failure;
    });
  }

  Future<Failure?> deleteBudget(String budgetId) {
    return _mutate((userId) async {
      return ref.read(budgetsRepositoryProvider).deleteBudget(userId, budgetId);
    });
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

      await _loadBudgets();
      return null;
    } finally {
      link.close();
    }
  }

  void refresh() {
    _loadBudgets();
  }
}
