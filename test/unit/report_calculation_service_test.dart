import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:eazyvault/features/accounts/data/datasources/accounts_remote_datasource.dart';
import 'package:eazyvault/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:eazyvault/features/categories/data/datasources/categories_remote_datasource.dart';
import 'package:eazyvault/features/categories/data/repositories/categories_repository_impl.dart';
import 'package:eazyvault/features/reports/domain/services/report_calculation_service.dart';
import 'package:eazyvault/features/transactions/data/datasources/transactions_remote_datasource.dart';
import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/models/loan_metadata.dart';
import 'package:eazyvault/features/transactions/domain/services/account_balance_service.dart';
import 'package:eazyvault/features/transactions/domain/services/loan_service.dart';
import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

/// Covers `ReportCalculationService` — the single source of truth every
/// report's PDF and Excel export reads from. Follows the same date rules as
/// the rest of the app: account balances/statements use the actual
/// transaction `date`; monthly income reporting uses `incomePeriod`.
void main() {
  group('ReportCalculationService', () {
    late ReportCalculationService service;
    late FakeFirebaseFirestore firestore;
    const userId = TestHelpers.testUserId;
    const accountId = 'account-1';
    const secondAccountId = 'account-2';
    const expenseCategoryId = 'category-expense';
    const incomeCategoryId = 'category-income';

    late TransactionsRepositoryImpl transactionsRepository;

    setUp(() async {
      firestore = MockFirebase.getFakeFirestore();
      final balanceService = AccountBalanceService(firestore: firestore);
      transactionsRepository = TransactionsRepositoryImpl(
        remoteDataSource: TransactionsRemoteDataSourceImpl(firestore: firestore),
        balanceService: balanceService,
      );
      final accountsRepository = AccountsRepositoryImpl(
        remoteDataSource: AccountsRemoteDataSourceImpl(firestore: firestore),
      );
      final categoriesRepository = CategoriesRepositoryImpl(
        remoteDataSource: CategoriesRemoteDataSourceImpl(firestore: firestore),
      );
      final loanService = LoanService(firestore: firestore, balanceService: balanceService);

      service = ReportCalculationService(
        transactionsRepository: transactionsRepository,
        accountsRepository: accountsRepository,
        categoriesRepository: categoriesRepository,
        loanService: loanService,
      );

      Future<void> seedAccount(String id, String name) {
        return firestore.collection('users').doc(userId).collection('accounts').doc(id).set({
          'name': name,
          'type': 'cash',
          'currentBalance': 0.0,
          'openingBalance': 0.0,
          'color': 0xFF4CAF50,
          'icon': '💵',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'createdBy': userId,
          'isDeleted': false,
        });
      }

      Future<void> seedCategory(String id, String name, String type) {
        return firestore.collection('users').doc(userId).collection('categories').doc(id).set({
          'name': name,
          'type': type,
          'isDefault': false,
          'color': 0xFF4CAF50,
          'icon': '💰',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'createdBy': userId,
          'isDeleted': false,
        });
      }

      await seedAccount(accountId, 'Cash');
      await seedAccount(secondAccountId, 'Bank');
      await seedCategory(expenseCategoryId, 'Food', 'expense');
      await seedCategory(incomeCategoryId, 'Salary', 'income');
    });

    Future<TransactionModel> createTransaction({
      required TransactionType type,
      required double amount,
      required DateTime date,
      String account = accountId,
      String? category,
      String? incomePeriod,
      Map<String, dynamic>? metadata,
    }) async {
      final now = DateTime.now();
      final result = await transactionsRepository.createTransaction(
        userId,
        TransactionModel(
          id: '',
          type: type,
          amount: amount,
          accountId: account,
          categoryId: category ?? (type == TransactionType.income ? incomeCategoryId : expenseCategoryId),
          date: date,
          incomePeriod: incomePeriod,
          metadata: metadata,
          createdAt: now,
          updatedAt: now,
          createdBy: userId,
        ),
      );
      expect(result.failure, isNull);
      return result.transaction!;
    }

    group('monthlyReport', () {
      test(
          'income credited Sep 30 but reported for October counts toward '
          'October; expense uses its own date', () async {
        await createTransaction(
          type: TransactionType.income,
          amount: 50000,
          date: DateTime(2026, 9, 30),
          incomePeriod: '2026-10',
        );
        await createTransaction(
          type: TransactionType.expense,
          amount: 10000,
          date: DateTime(2026, 10, 1),
        );

        final data = await service.monthlyReport(userId, DateTime(2026, 10, 15));

        expect(data.income, 50000);
        expect(data.expense, 10000);
        expect(data.netSavings, 40000);
        expect(data.transactionCount, 2);
        // Account balance already reflects both the Sep 30 credit and the
        // Oct 1 debit, independent of the reporting period.
        expect(data.totalBalance, 40000);
      });

      test('empty month returns zeros, not a crash', () async {
        final data = await service.monthlyReport(userId, DateTime(2030, 1, 1));
        expect(data.income, 0);
        expect(data.expense, 0);
        expect(data.transactionCount, 0);
        expect(data.incomeByCategory, isEmpty);
        expect(data.expenseByCategory, isEmpty);
      });
    });

    group('accountStatement', () {
      test('running balance follows actual transaction dates, not incomePeriod', () async {
        await createTransaction(
          type: TransactionType.income,
          amount: 50000,
          date: DateTime(2026, 9, 30),
          incomePeriod: '2026-10',
        );
        await createTransaction(
          type: TransactionType.expense,
          amount: 10000,
          date: DateTime(2026, 10, 1),
        );

        final data = await service.accountStatement(
          userId,
          accountId,
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 10, 31, 23, 59, 59),
        );

        expect(data.openingBalance, 0);
        expect(data.lines, hasLength(2));
        expect(data.lines[0].credit, 50000);
        expect(data.lines[0].runningBalance, 50000);
        expect(data.lines[1].debit, 10000);
        expect(data.lines[1].runningBalance, 40000);
        expect(data.closingBalance, 40000);
        expect(data.totalDebits, 10000);
        expect(data.totalCredits, 50000);
      });

      test('a transfer credits the destination account even though accountId is the source', () async {
        final now = DateTime.now();
        await transactionsRepository.createTransaction(
          userId,
          TransactionModel(
            id: '',
            type: TransactionType.transfer,
            amount: 1000,
            accountId: accountId,
            categoryId: 'transfer',
            date: DateTime(2026, 10, 5),
            metadata: {'fromAccountId': accountId, 'toAccountId': secondAccountId},
            createdAt: now,
            updatedAt: now,
            createdBy: userId,
          ),
        );

        final destinationStatement = await service.accountStatement(userId, secondAccountId);
        expect(destinationStatement.lines, hasLength(1));
        expect(destinationStatement.lines.single.credit, 1000);
        expect(destinationStatement.closingBalance, 1000);

        final sourceStatement = await service.accountStatement(userId, accountId);
        expect(sourceStatement.lines, hasLength(1));
        expect(sourceStatement.lines.single.debit, 1000);
        expect(sourceStatement.closingBalance, -1000);
      });

      test('a start date excludes earlier lines but keeps their effect in the opening balance', () async {
        await createTransaction(type: TransactionType.income, amount: 1000, date: DateTime(2026, 1, 1));
        await createTransaction(type: TransactionType.income, amount: 500, date: DateTime(2026, 6, 1));

        final data = await service.accountStatement(
          userId,
          accountId,
          startDate: DateTime(2026, 6, 1),
        );

        expect(data.openingBalance, 1000);
        expect(data.lines, hasLength(1));
        expect(data.closingBalance, 1500);
      });
    });

    group('incomeReport', () {
      test('falls back to the credited month when incomePeriod is unset (legacy records)', () async {
        await firestore.collection('users').doc(userId).collection('transactions').doc('legacy').set({
          'type': 'income',
          'amount': 20000.0,
          'accountId': accountId,
          'categoryId': incomeCategoryId,
          'date': Timestamp.fromDate(DateTime(2026, 6, 15)),
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'createdBy': userId,
          'isDeleted': false,
        });

        final data = await service.incomeReport(
          userId,
          startPeriod: DateTime(2026, 6, 1),
          endPeriod: DateTime(2026, 6, 30),
        );

        expect(data.rows, hasLength(1));
        expect(data.total, 20000);
      });

      test('filters by account and category', () async {
        await createTransaction(type: TransactionType.income, amount: 1000, date: DateTime(2026, 3, 1), account: accountId);
        await createTransaction(type: TransactionType.income, amount: 2000, date: DateTime(2026, 3, 1), account: secondAccountId);

        final data = await service.incomeReport(
          userId,
          startPeriod: DateTime(2026, 3, 1),
          endPeriod: DateTime(2026, 3, 31),
          accountId: accountId,
        );

        expect(data.rows, hasLength(1));
        expect(data.total, 1000);
      });
    });

    group('expenseReport', () {
      test('groups by category with correct counts and totals', () async {
        await createTransaction(type: TransactionType.expense, amount: 100, date: DateTime(2026, 4, 1));
        await createTransaction(type: TransactionType.expense, amount: 200, date: DateTime(2026, 4, 2));

        final data = await service.expenseReport(
          userId,
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 30),
        );

        expect(data.total, 300);
        expect(data.byCategory, hasLength(1));
        expect(data.byCategory.single.transactionCount, 2);
        expect(data.byCategory.single.percentage, 100);
      });
    });

    group('categoryReport', () {
      test('percentages add up to 100 across categories', () async {
        await firestore.collection('users').doc(userId).collection('categories').doc('category-expense-2').set({
          'name': 'Travel',
          'type': 'expense',
          'isDefault': false,
          'color': 0xFF4CAF50,
          'icon': '✈️',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'createdBy': userId,
          'isDeleted': false,
        });

        await createTransaction(type: TransactionType.expense, amount: 300, date: DateTime(2026, 5, 1));
        await createTransaction(
          type: TransactionType.expense,
          amount: 700,
          date: DateTime(2026, 5, 2),
          category: 'category-expense-2',
        );

        final data = await service.categoryReport(
          userId,
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 31),
        );

        expect(data.totalExpense, 1000);
        final totalPercentage = data.expenseByCategory.fold<double>(0, (sum, r) => sum + r.percentage);
        expect(totalPercentage, closeTo(100, 0.01));
      });
    });

    group('loanDebtReport', () {
      test('separates money given (owed to you) from money taken (you owe)', () async {
        final now = DateTime.now();
        await transactionsRepository.createTransaction(
          userId,
          TransactionModel(
            id: '',
            type: TransactionType.loanGiven,
            amount: 5000,
            accountId: accountId,
            categoryId: 'loan',
            date: now,
            metadata: const LoanMetadata(
              partyName: 'Alice',
              originalAmount: 5000,
              remainingAmount: 5000,
            ).toJson(),
            createdAt: now,
            updatedAt: now,
            createdBy: userId,
          ),
        );
        await transactionsRepository.createTransaction(
          userId,
          TransactionModel(
            id: '',
            type: TransactionType.loanTaken,
            amount: 2000,
            accountId: accountId,
            categoryId: 'loan',
            date: now,
            metadata: const LoanMetadata(
              partyName: 'Bob',
              originalAmount: 2000,
              remainingAmount: 2000,
            ).toJson(),
            createdAt: now,
            updatedAt: now,
            createdBy: userId,
          ),
        );

        final data = await service.loanDebtReport(userId);

        expect(data.owedToYou, hasLength(1));
        expect(data.owedToYou.single.partyName, 'Alice');
        expect(data.totalOwedToYou, 5000);
        expect(data.youOwe, hasLength(1));
        expect(data.youOwe.single.partyName, 'Bob');
        expect(data.totalYouOwe, 2000);
        expect(data.netPosition, 3000);
      });
    });

    group('annualReport', () {
      test('Dec 31 income reported for January belongs to next year\'s annual report', () async {
        await createTransaction(
          type: TransactionType.income,
          amount: 50000,
          date: DateTime(2026, 12, 31),
          incomePeriod: '2027-01',
        );

        final report2026 = await service.annualReport(userId, 2026);
        final report2027 = await service.annualReport(userId, 2027);

        expect(report2026.totalIncome, 0);
        expect(report2027.totalIncome, 50000);
        expect(report2027.monthly.first.month, DateTime(2027, 1));
        expect(report2027.monthly.first.income, 50000);
        expect(report2027.monthly, hasLength(12));
      });

      test('an empty year has 12 zeroed months, not a crash', () async {
        final data = await service.annualReport(userId, 2099);
        expect(data.monthly, hasLength(12));
        expect(data.totalIncome, 0);
        expect(data.totalExpense, 0);
      });
    });
  });
}
