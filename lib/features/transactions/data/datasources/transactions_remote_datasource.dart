import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/extensions/transaction_extensions.dart';
import '../../domain/utils/income_period.dart';
import '../models/transaction_model.dart';
import '../../../../core/utils/error_messages.dart';

abstract class TransactionsRemoteDataSource {
  Future<({List<TransactionModel> transactions, DocumentSnapshot? lastDocument})> getTransactions(
    String userId, {
    TransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    DocumentSnapshot? lastDocument,
  });

  Future<TransactionModel> getTransaction(String userId, String transactionId);
  
  Stream<List<TransactionModel>> watchTransactions(
    String userId, {
    TransactionType? type,
    int? limit,
  });

  Future<double> getTotalByType(
    String userId,
    TransactionType type, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Expense is bucketed by its actual date; income by its reporting period
  /// (`incomePeriod`, falling back to `date`'s month) — see
  /// `TransactionModelExtensions.effectiveIncomePeriod`.
  Future<Map<String, ({double income, double expense})>> getTotalsByAccount(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Expense totals per category id for transactions dated in
  /// [startDate]..[endDate]. Income and transfer/loan transactions (which use
  /// the sentinel `'transfer'`/`'loan'` category ids) are excluded.
  Future<Map<String, double>> getExpenseTotalsByCategory(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Income/expense totals per calendar month (keyed by the first day of the
  /// month, local time). Expense is bucketed by its actual date in
  /// [startDate]..[endDate]; income by its reporting period (`incomePeriod`,
  /// falling back to `date`'s month) in that same window.
  Future<Map<DateTime, ({double income, double expense})>> getMonthlyTotals(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Income transactions whose *effective* reporting period falls in
  /// [startPeriod]..[endPeriod] (every income transaction when both are
  /// null), for reports that need the actual rows rather than just a total.
  /// Same incomePeriod/date hybrid query as the aggregate methods above.
  Future<List<TransactionModel>> getIncomeTransactions(
    String userId, {
    DateTime? startPeriod,
    DateTime? endPeriod,
  });

  /// Every non-deleted transaction affecting [accountId]'s balance, dated on
  /// or before [endDate] (all of history when null — a correct running
  /// balance needs everything before the statement's start too), sorted
  /// ascending by date. Covers both the account's own records (`accountId`)
  /// and transfers where it's only the destination (`metadata.toAccountId`,
  /// which plain `accountId` equality misses).
  Future<List<TransactionModel>> getAccountHistory(
    String userId,
    String accountId, {
    DateTime? endDate,
  });
}

class TransactionsRemoteDataSourceImpl implements TransactionsRemoteDataSource {
  TransactionsRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _transactionsCollection(String userId) {
    return _firestore
        .collection(AppConstants.userCollection)
        .doc(userId)
        .collection(AppConstants.transactionsCollection);
  }

  /// Non-deleted income transactions whose *effective* reporting month
  /// (`TransactionModelExtensions.effectiveIncomePeriod`) falls in
  /// [startDate]..[endDate] (both required; otherwise every income
  /// transaction is returned, matching the old unfiltered behavior).
  ///
  /// Monthly income reporting uses `incomePeriod`, not the credited `date`
  /// (see CLAUDE.md "Income Reporting Period"), so this combines two
  /// indexed queries instead of one plain date-range scan:
  /// - `incomePeriod` in range: catches income with an explicit reporting
  ///   period, however far that period is from its credited date.
  /// - `date` in range: catches income with no explicit `incomePeriod`
  ///   (legacy records from before this field existed, and anything
  ///   auto-generated without one) — for those, the effective period is the
  ///   credited date's own month, which is covered by this query whenever
  ///   that month falls in the window.
  /// Results are deduped by document id and re-filtered by effective period,
  /// since either query can return a document the other also matches, or
  /// one whose raw `date` is in range but whose *effective* period (an
  /// explicit, different incomePeriod) is not.
  @override
  Future<List<TransactionModel>> getIncomeTransactions(
    String userId, {
    DateTime? startPeriod,
    DateTime? endPeriod,
  }) =>
      _getIncomeTransactions(userId, startDate: startPeriod, endDate: endPeriod);

  Future<List<TransactionModel>> _getIncomeTransactions(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (startDate == null || endDate == null) {
      final snapshot = await _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('type', isEqualTo: TransactionType.income.name)
          .get();
      return snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
    }

    final startKey = IncomePeriod.of(startDate);
    final endKey = IncomePeriod.of(endDate);

    final byPeriod = await _transactionsCollection(userId)
        .where(AppConstants.isDeletedField, isEqualTo: false)
        .where('type', isEqualTo: TransactionType.income.name)
        .where('incomePeriod', isGreaterThanOrEqualTo: startKey)
        .where('incomePeriod', isLessThanOrEqualTo: endKey)
        .get();

    final byDate = await _transactionsCollection(userId)
        .where(AppConstants.isDeletedField, isEqualTo: false)
        .where('type', isEqualTo: TransactionType.income.name)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final merged = <String, TransactionModel>{};
    for (final doc in [...byPeriod.docs, ...byDate.docs]) {
      merged[doc.id] = TransactionModel.fromFirestore(doc);
    }

    return merged.values
        .where((t) =>
            t.effectiveIncomePeriod.compareTo(startKey) >= 0 &&
            t.effectiveIncomePeriod.compareTo(endKey) <= 0)
        .toList();
  }

  @override
  Future<({List<TransactionModel> transactions, DocumentSnapshot? lastDocument})> getTransactions(
    String userId, {
    TransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      LoggerService.info('Fetching transactions for user: $userId');

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (accountId != null) {
        query = query.where('accountId', isEqualTo: accountId);
      }

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('date', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      if (limit != null) {
        query = query.limit(limit);
      } else {
        query = query.limit(AppConfig.defaultPageSize);
      }

      final querySnapshot = await query.get();

      final transactions = querySnapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      final lastDoc = querySnapshot.docs.isNotEmpty 
          ? querySnapshot.docs.last 
          : null;

      LoggerService.info('Fetched ${transactions.length} transactions');
      return (transactions: transactions, lastDocument: lastDoc);
    } catch (e, stackTrace) {
      LoggerService.error('Get transactions error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'load transactions'));
    }
  }

  @override
  Future<TransactionModel> getTransaction(String userId, String transactionId) async {
    try {
      LoggerService.info('Fetching transaction: $transactionId');

      final doc = await _transactionsCollection(userId).doc(transactionId).get();

      if (!doc.exists) {
        throw const NotFoundException('Transaction not found');
      }

      return TransactionModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      LoggerService.error('Get transaction error', error: e, stackTrace: stackTrace);
      if (e is NotFoundException) rethrow;
      throw ServerException(ErrorMessages.from(e, action: 'load transaction'));
    }
  }

  @override
  Stream<List<TransactionModel>> watchTransactions(
    String userId, {
    TransactionType? type,
    int? limit,
  }) {
    try {
      LoggerService.info('Watching transactions for user: $userId');

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      query = query
          .orderBy('date', descending: true)
          .limit(limit ?? AppConfig.defaultPageSize);

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList();
      });
    } catch (e, stackTrace) {
      LoggerService.error('Watch transactions error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'load transactions'));
    }
  }

  @override
  Future<double> getTotalByType(
    String userId,
    TransactionType type, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      LoggerService.info('Calculating total for type: ${type.name}');

      if (type == TransactionType.income) {
        final income = await _getIncomeTransactions(
          userId,
          startDate: startDate,
          endDate: endDate,
        );
        final total = income.fold<double>(0, (sum, t) => sum + t.amount);
        LoggerService.info('Total for ${type.name}: $total');
        return total;
      }

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('type', isEqualTo: type.name);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();

      final total = querySnapshot.docs.fold<double>(
        0,
        (sum, doc) => sum + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
      );

      LoggerService.info('Total for ${type.name}: $total');
      return total;
    } catch (e, stackTrace) {
      LoggerService.error('Get total error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'calculate total'));
    }
  }

  @override
  Future<Map<String, ({double income, double expense})>> getTotalsByAccount(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      LoggerService.info('Calculating totals by account');

      // Expense keeps using the actual expense date. Income is aggregated
      // separately below by its reporting period instead of `date`.
      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('type', isEqualTo: TransactionType.expense.name);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();

      final accountTotals = <String, ({double income, double expense})>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final accountId = data['accountId'] as String?;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;

        if (accountId != null) {
          final current = accountTotals[accountId] ?? (income: 0.0, expense: 0.0);
          accountTotals[accountId] = (income: current.income, expense: current.expense + amount);
        }
      }

      final income = await _getIncomeTransactions(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      for (final transaction in income) {
        final current =
            accountTotals[transaction.accountId] ?? (income: 0.0, expense: 0.0);
        accountTotals[transaction.accountId] =
            (income: current.income + transaction.amount, expense: current.expense);
      }

      LoggerService.info('Calculated totals for ${accountTotals.length} accounts');
      return accountTotals;
    } catch (e, stackTrace) {
      LoggerService.error('Get totals by account error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'calculate totals by account'));
    }
  }

  @override
  Future<Map<String, double>> getExpenseTotalsByCategory(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      LoggerService.info('Calculating expense totals by category');

      Query<Map<String, dynamic>> query = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('type', isEqualTo: TransactionType.expense.name);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();

      final categoryTotals = <String, double>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final categoryId = data['categoryId'] as String?;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;

        if (categoryId != null) {
          categoryTotals[categoryId] = (categoryTotals[categoryId] ?? 0) + amount;
        }
      }

      LoggerService.info('Calculated expense totals for ${categoryTotals.length} categories');
      return categoryTotals;
    } catch (e, stackTrace) {
      LoggerService.error('Get expense totals by category error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to calculate expense totals by category: ${e.toString()}');
    }
  }

  @override
  Future<Map<DateTime, ({double income, double expense})>> getMonthlyTotals(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final totals = <DateTime, ({double income, double expense})>{};

      // Expense keeps bucketing by its actual date.
      final expenseSnapshot = await _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('type', isEqualTo: TransactionType.expense.name)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      for (final doc in expenseSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) continue;

        final month = DateTime(date.year, date.month);
        final current = totals[month] ?? (income: 0.0, expense: 0.0);
        totals[month] = (income: current.income, expense: current.expense + amount);
      }

      // Income buckets by its reporting period instead.
      final income = await _getIncomeTransactions(
        userId,
        startDate: startDate,
        endDate: endDate,
      );
      for (final transaction in income) {
        final month = transaction.incomeReportingMonth;
        final current = totals[month] ?? (income: 0.0, expense: 0.0);
        totals[month] = (income: current.income + transaction.amount, expense: current.expense);
      }

      return totals;
    } catch (e, stackTrace) {
      LoggerService.error('Get monthly totals error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'calculate monthly totals'));
    }
  }

  @override
  Future<List<TransactionModel>> getAccountHistory(
    String userId,
    String accountId, {
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> ownQuery = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('accountId', isEqualTo: accountId);
      Query<Map<String, dynamic>> transferInQuery = _transactionsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .where('type', isEqualTo: TransactionType.transfer.name)
          .where('metadata.toAccountId', isEqualTo: accountId);

      if (endDate != null) {
        final endTimestamp = Timestamp.fromDate(endDate);
        ownQuery = ownQuery.where('date', isLessThanOrEqualTo: endTimestamp);
        transferInQuery = transferInQuery.where('date', isLessThanOrEqualTo: endTimestamp);
      }

      final results = await Future.wait([ownQuery.get(), transferInQuery.get()]);

      final merged = <String, TransactionModel>{};
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          merged[doc.id] = TransactionModel.fromFirestore(doc);
        }
      }

      final transactions = merged.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return transactions;
    } catch (e, stackTrace) {
      LoggerService.error('Get account history error', error: e, stackTrace: stackTrace);
      throw ServerException(ErrorMessages.from(e, action: 'load account history'));
    }
  }
}
