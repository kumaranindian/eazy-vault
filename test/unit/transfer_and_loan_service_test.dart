import 'package:eazyvault/core/exceptions/app_exception.dart';
import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/models/loan_metadata.dart';
import 'package:eazyvault/features/transactions/domain/services/account_balance_service.dart';
import 'package:eazyvault/features/transactions/domain/services/loan_service.dart';
import 'package:eazyvault/features/transactions/domain/services/transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

void main() {
  const userId = TestHelpers.testUserId;
  late FakeFirebaseFirestore firestore;
  late AccountBalanceService balanceService;

  Future<double> balanceOf(String accountId) async {
    final doc = await firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc(accountId)
        .get();
    return (doc.data()!['currentBalance'] as num).toDouble();
  }

  setUp(() async {
    firestore = MockFirebase.getFakeFirestore();
    balanceService = AccountBalanceService(firestore: firestore);
    await MockFirebase.seedFirestore(firestore, userId);
  });

  group('TransferService', () {
    test('creates exactly one record and moves the amount once', () async {
      final service = TransferService(balanceService: balanceService);
      final created = await service.createTransfer(
        userId: userId,
        fromAccountId: 'account-1',
        toAccountId: 'account-2',
        amount: 100,
        date: DateTime.now(),
      );

      expect(await balanceOf('account-1'), 9900);
      expect(await balanceOf('account-2'), 50100);
      expect(created.type, TransactionType.transfer);

      final transfers = await firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .where('type', isEqualTo: 'transfer')
          .get();
      expect(transfers.docs.length, 1);
    });

    test('rejects insufficient balance without writing anything', () async {
      final service = TransferService(balanceService: balanceService);
      await expectLater(
        service.createTransfer(
          userId: userId,
          fromAccountId: 'account-1',
          toAccountId: 'account-2',
          amount: 20000,
          date: DateTime.now(),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(await balanceOf('account-1'), 10000);
    });
  });

  group('LoanService.recordRepayment', () {
    test('records the repayment and updates the loan atomically', () async {
      final loanService = LoanService(firestore: firestore, balanceService: balanceService);
      final now = DateTime.now();
      final loan = await balanceService.createTransaction(
        userId,
        TransactionModel(
          id: '',
          type: TransactionType.loanGiven,
          amount: 1000,
          accountId: 'account-1',
          categoryId: 'loan',
          date: now,
          metadata: const LoanMetadata(originalAmount: 1000, remainingAmount: 1000).toJson(),
          createdAt: now,
          updatedAt: now,
          createdBy: userId,
        ),
      );

      await loanService.recordRepayment(
        userId: userId,
        repayment: TransactionModel(
          id: '',
          type: TransactionType.loanRepayment,
          amount: 250,
          accountId: 'account-2',
          categoryId: 'loan',
          date: now,
          metadata: LoanMetadata(linkedLoanId: loan.id).toJson(),
          createdAt: now,
          updatedAt: now,
          createdBy: userId,
        ),
      );

      expect(await balanceOf('account-1'), 9000);
      expect(await balanceOf('account-2'), 50250);

      final active = await loanService.getActiveLoans(userId);
      final remaining = LoanMetadata.fromJson(active.loansGiven.single.metadata!).remainingAmount;
      expect(remaining, 750);
    });
  });
}
