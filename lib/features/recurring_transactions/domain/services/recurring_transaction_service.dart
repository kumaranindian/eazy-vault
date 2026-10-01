import '../../../../core/services/logger_service.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/repositories/transactions_repository.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../extensions/recurring_transaction_extensions.dart';
import '../repositories/recurring_transactions_repository.dart';

/// Generates the transactions a recurring rule owes since it was last run.
/// Runs client-side when the app is opened (see
/// `recurring_catch_up_provider.dart`) — there is no server-side scheduler,
/// so a rule only catches up the next time someone opens the app.
class RecurringTransactionService {
  RecurringTransactionService({
    required RecurringTransactionsRepository recurringRepository,
    required TransactionsRepository transactionsRepository,
  })  : _recurringRepository = recurringRepository,
        _transactionsRepository = transactionsRepository;

  final RecurringTransactionsRepository _recurringRepository;
  final TransactionsRepository _transactionsRepository;

  /// Safety bound on how many occurrences a single catch-up will backfill
  /// for one rule, in case a rule has gone unattended for a very long time.
  static const int maxOccurrencesPerRun = 24;

  /// Creates one transaction per occurrence of [rule] due on or before
  /// [asOf] (today, by default), advancing `lastGeneratedDate` after each
  /// one. Transactions are created sequentially and through
  /// [TransactionsRepository.createTransaction] — the same path the UI uses
  /// — so balances update exactly as they would for a manually entered
  /// transaction. Returns how many were created.
  Future<int> catchUp(String userId, RecurringTransactionModel rule, {DateTime? asOf}) async {
    final now = asOf ?? DateTime.now();
    var current = rule;
    var generatedCount = 0;

    while (generatedCount < maxOccurrencesPerRun && current.isDueBy(now)) {
      final dueDate = current.nextDueDate;

      final transaction = TransactionModel(
        id: '',
        type: current.type,
        amount: current.amount,
        accountId: current.accountId,
        categoryId: current.categoryId,
        date: dueDate,
        description: current.description,
        vendor: current.vendor,
        metadata: {'recurringRuleId': current.id},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
      );

      final result = await _transactionsRepository.createTransaction(userId, transaction);
      if (result.failure != null) {
        LoggerService.error(
          'Failed to generate recurring transaction for rule ${current.id}',
          error: result.failure,
        );
        break;
      }

      current = current.copyWith(lastGeneratedDate: dueDate);
      generatedCount++;
    }

    if (generatedCount > 0) {
      final updateResult =
          await _recurringRepository.updateRecurringTransaction(userId, current);
      if (updateResult.failure != null) {
        LoggerService.error(
          'Failed to advance lastGeneratedDate for rule ${current.id}',
          error: updateResult.failure,
        );
      }
    }

    return generatedCount;
  }

  /// Runs [catchUp] for every active rule. Returns the total number of
  /// transactions created across all rules.
  Future<int> catchUpAll(String userId, {DateTime? asOf}) async {
    final result = await _recurringRepository.getRecurringTransactions(userId);
    if (result.failure != null) {
      LoggerService.error('Failed to load recurring transactions', error: result.failure);
      return 0;
    }

    var total = 0;
    for (final rule in result.rules.where((r) => r.isActive)) {
      total += await catchUp(userId, rule, asOf: asOf);
    }
    return total;
  }
}
