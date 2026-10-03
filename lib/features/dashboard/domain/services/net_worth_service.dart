import '../../../accounts/domain/repositories/accounts_repository.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/domain/repositories/transactions_repository.dart';
import '../../../transactions/domain/services/account_balance_service.dart';
import '../models/net_worth_point.dart';
import 'net_worth_calculator.dart';

/// Computes a net-worth-over-time series from existing transaction history —
/// there's no balance-snapshot collection, so this reconstructs it the same
/// way `AccountBalanceService.recalculateBalances` and the account-statement
/// report do: opening balances plus every transaction's signed effect,
/// replayed in order. Reuses `AccountBalanceService.signedAmountFor` (the
/// same primitive account statements use) rather than recomputing balance
/// math — never add a second place that re-derives it.
class NetWorthService {
  NetWorthService({
    required AccountsRepository accountsRepository,
    required TransactionsRepository transactionsRepository,
  })  : _accountsRepository = accountsRepository,
        _transactionsRepository = transactionsRepository;

  final AccountsRepository _accountsRepository;
  final TransactionsRepository _transactionsRepository;

  Future<List<NetWorthPoint>> computeHistory(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final accountsResult = await _accountsRepository.getAccounts(userId);
    if (accountsResult.failure != null) {
      throw Exception(accountsResult.failure!.message);
    }
    final accounts = accountsResult.accounts;
    if (accounts.isEmpty) return [];

    final openingNetWorth =
        accounts.fold<double>(0, (sum, account) => sum + account.openingBalance);

    // Every account's history, plus a lookup by id across all of them so a
    // loanRepayment (whose direction depends on the linked loan's type) can
    // resolve that loan even if it lives in a different account's history.
    final historiesByAccount = <String, List<TransactionModel>>{};
    final allById = <String, TransactionModel>{};
    for (final account in accounts) {
      final result = await _transactionsRepository.getAccountHistory(
        userId,
        account.id,
        endDate: endDate,
      );
      if (result.failure != null) {
        throw Exception(result.failure!.message);
      }
      historiesByAccount[account.id] = result.transactions;
      for (final transaction in result.transactions) {
        allById[transaction.id] = transaction;
      }
    }

    final deltas = <NetWorthDelta>[];
    for (final account in accounts) {
      for (final transaction in historiesByAccount[account.id]!) {
        TransactionType? linkedLoanType;
        if (transaction.type == TransactionType.loanRepayment) {
          final linkedLoanId = transaction.metadata?['linkedLoanId'] as String?;
          linkedLoanType = linkedLoanId == null ? null : allById[linkedLoanId]?.type;
        }
        final delta = AccountBalanceService.signedAmountFor(
          transaction,
          account.id,
          linkedLoanType: linkedLoanType,
        );
        if (delta != 0) {
          deltas.add((date: transaction.date, delta: delta));
        }
      }
    }

    return NetWorthCalculator.build(
      openingNetWorth: openingNetWorth,
      deltas: deltas,
      startDate: startDate,
      endDate: endDate,
      granularity: NetWorthGranularity.forRange(startDate, endDate),
    );
  }
}
