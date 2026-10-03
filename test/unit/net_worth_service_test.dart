import 'package:eazyvault/features/accounts/data/datasources/accounts_remote_datasource.dart';
import 'package:eazyvault/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:eazyvault/features/dashboard/domain/services/net_worth_service.dart';
import 'package:eazyvault/features/transactions/data/datasources/transactions_remote_datasource.dart';
import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/services/account_balance_service.dart';
import 'package:eazyvault/features/transactions/domain/services/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

/// Seeded accounts: account-1 (cash, opening 10000) + account-2 (savings,
/// opening 50000) => opening net worth 60000. The seeded transaction-1 is
/// dated "now" (far after this test's Feb-2026 range), so `getAccountHistory`
/// (bounded by `endDate`) never fetches it — it has no effect here.
void main() {
  const userId = TestHelpers.testUserId;

  test('a transfer between own accounts nets to zero; income still raises net worth', () async {
    final firestore = MockFirebase.getFakeFirestore();
    await MockFirebase.seedFirestore(firestore, userId);

    final balanceService = AccountBalanceService(firestore: firestore);
    final service = NetWorthService(
      accountsRepository:
          AccountsRepositoryImpl(remoteDataSource: AccountsRemoteDataSourceImpl(firestore: firestore)),
      transactionsRepository: TransactionsRepositoryImpl(
        remoteDataSource: TransactionsRemoteDataSourceImpl(firestore: firestore),
        balanceService: balanceService,
      ),
    );

    final rangeStart = DateTime(2026, 2, 1);
    final incomeDate = DateTime(2026, 2, 3);
    final transferDate = DateTime(2026, 2, 7);
    final rangeEnd = DateTime(2026, 2, 10);

    await balanceService.createTransaction(
      userId,
      TransactionModel(
        id: '',
        type: TransactionType.income,
        amount: 2000,
        accountId: 'account-1',
        categoryId: 'category-2',
        date: incomeDate,
        createdAt: incomeDate,
        updatedAt: incomeDate,
        createdBy: userId,
      ),
    );

    await TransferService(balanceService: balanceService).createTransfer(
      userId: userId,
      fromAccountId: 'account-1',
      toAccountId: 'account-2',
      amount: 1000,
      date: transferDate,
    );

    final history = await service.computeHistory(
      userId,
      startDate: rangeStart,
      endDate: rangeEnd,
    );
    final byDate = {for (final p in history) p.date: p.netWorth};

    expect(byDate[rangeStart], 60000); // before the income lands
    expect(byDate[incomeDate], 62000); // +2000 income
    expect(byDate[transferDate], 62000); // transfer nets to zero
    expect(byDate[rangeEnd], 62000);
  });
}
