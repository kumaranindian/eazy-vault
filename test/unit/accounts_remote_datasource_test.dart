import 'package:eazyvault/core/exceptions/app_exception.dart';
import 'package:eazyvault/features/accounts/data/datasources/accounts_remote_datasource.dart';
import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/services/account_balance_service.dart';
import 'package:eazyvault/features/transactions/domain/services/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

void main() {
  const userId = TestHelpers.testUserId;
  late FakeFirebaseFirestore firestore;
  late AccountsRemoteDataSourceImpl dataSource;

  setUp(() async {
    firestore = MockFirebase.getFakeFirestore();
    dataSource = AccountsRemoteDataSourceImpl(firestore: firestore);
    await MockFirebase.seedFirestore(firestore, userId);
  });

  group('updateAccount', () {
    test('applies an opening balance change to the current balance', () async {
      final account = await dataSource.getAccount(userId, 'account-1');
      final updated = await dataSource.updateAccount(
        userId,
        account.copyWith(openingBalance: account.openingBalance + 250),
      );
      expect(updated.currentBalance, account.currentBalance + 250);
    });

    test('never writes a stale current balance from the client copy', () async {
      final staleCopy = await dataSource.getAccount(userId, 'account-1');

      // A transaction changes the balance while the edit form is open.
      await AccountBalanceService(firestore: firestore).createTransaction(
        userId,
        TransactionModel(
          id: '',
          type: TransactionType.income,
          amount: 100,
          accountId: 'account-1',
          categoryId: 'category-2',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: userId,
        ),
      );

      final updated = await dataSource.updateAccount(
        userId,
        staleCopy.copyWith(name: 'Wallet'),
      );
      expect(updated.name, 'Wallet');
      expect(updated.currentBalance, staleCopy.currentBalance + 100);
    });
  });

  group('deleteAccount', () {
    test('is rejected while the account has transactions', () async {
      await expectLater(
        dataSource.deleteAccount(userId, 'account-1'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('is rejected while the account receives a transfer', () async {
      await TransferService(
        balanceService: AccountBalanceService(firestore: firestore),
      ).createTransfer(
        userId: userId,
        fromAccountId: 'account-1',
        toAccountId: 'account-2',
        amount: 10,
        date: DateTime.now(),
      );
      await expectLater(
        dataSource.deleteAccount(userId, 'account-2'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('soft-deletes an unused account, which is then not found', () async {
      await dataSource.deleteAccount(userId, 'account-2');
      await expectLater(
        dataSource.getAccount(userId, 'account-2'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
