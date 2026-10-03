import 'package:eazyvault/core/exceptions/app_exception.dart';
import 'package:eazyvault/features/transactions/data/models/transaction_model.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:eazyvault/features/transactions/domain/models/loan_metadata.dart';
import 'package:eazyvault/features/transactions/domain/services/account_balance_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

void main() {
  const userId = TestHelpers.testUserId;
  late FakeFirebaseFirestore firestore;
  late AccountBalanceService service;

  // Seeded balances (see MockFirebase.seedFirestore).
  const cashStart = 10000.0; // account-1
  const bankStart = 50000.0; // account-2

  Future<double> balanceOf(String accountId) async {
    final doc = await firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc(accountId)
        .get();
    return (doc.data()!['currentBalance'] as num).toDouble();
  }

  Future<Map<String, dynamic>> transactionDoc(String id) async {
    final doc = await firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(id)
        .get();
    return doc.data()!;
  }

  TransactionModel tx(
    TransactionType type,
    double amount, {
    String accountId = 'account-1',
    String categoryId = 'category-1',
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return TransactionModel(
      id: '',
      type: type,
      amount: amount,
      accountId: accountId,
      categoryId: categoryId,
      date: now,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
      createdBy: userId,
    );
  }

  TransactionModel loan(TransactionType type, double amount) => tx(
        type,
        amount,
        categoryId: 'loan',
        metadata: LoanMetadata(
          partyName: 'Friend',
          originalAmount: amount,
          remainingAmount: amount,
        ).toJson(),
      );

  TransactionModel repayment(String loanId, double amount) => tx(
        TransactionType.loanRepayment,
        amount,
        categoryId: 'loan',
        metadata: LoanMetadata(linkedLoanId: loanId).toJson(),
      );

  TransactionModel transfer(double amount, {String from = 'account-1', String to = 'account-2'}) => tx(
        TransactionType.transfer,
        amount,
        accountId: from,
        categoryId: 'transfer',
        metadata: TransferMetadata(fromAccountId: from, toAccountId: to).toJson(),
      );

  setUp(() async {
    firestore = MockFirebase.getFakeFirestore();
    service = AccountBalanceService(firestore: firestore);
    await MockFirebase.seedFirestore(firestore, userId);
  });

  group('create applies the balance effect of each type', () {
    test('income adds to the account', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.income, 1000));
      expect(await balanceOf('account-1'), cashStart + 1000);
      expect((await transactionDoc(created.id))['amount'], 1000);
    });

    test('expense subtracts from the account', () async {
      await service.createTransaction(userId, tx(TransactionType.expense, 300));
      expect(await balanceOf('account-1'), cashStart - 300);
    });

    test('loan taken adds to the account (money borrowed comes in)', () async {
      await service.createTransaction(userId, loan(TransactionType.loanTaken, 500));
      expect(await balanceOf('account-1'), cashStart + 500);
    });

    test('loan given subtracts from the account (money lent goes out)', () async {
      await service.createTransaction(userId, loan(TransactionType.loanGiven, 500));
      expect(await balanceOf('account-1'), cashStart - 500);
    });

    test('transfer debits source once and credits destination once', () async {
      final created = await service.createTransaction(userId, transfer(100));
      expect(await balanceOf('account-1'), cashStart - 100);
      expect(await balanceOf('account-2'), bankStart + 100);
      expect((await transactionDoc(created.id))['type'], 'transfer');
    });

    test('transfer is rejected when the source would go negative', () async {
      await expectLater(
        service.createTransaction(
          userId,
          transfer(cashStart + 1),
          nonNegativeAccountId: 'account-1',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(await balanceOf('account-1'), cashStart);
      expect(await balanceOf('account-2'), bankStart);
    });

    test('transfer to the same account is rejected', () async {
      await expectLater(
        service.createTransaction(userId, transfer(10, to: 'account-1')),
        throwsA(isA<ValidationException>()),
      );
    });

    test('zero amount is rejected', () async {
      await expectLater(
        service.createTransaction(userId, tx(TransactionType.expense, 0)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('missing account rejects the whole write', () async {
      await expectLater(
        service.createTransaction(userId, tx(TransactionType.income, 10, accountId: 'nope')),
        throwsA(isA<NotFoundException>()),
      );
      final all = await firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .get();
      expect(all.docs.length, 1, reason: 'only the seeded transaction exists');
    });
  });

  group('loan repayments', () {
    test('repaying a loan you gave adds money and reduces remaining', () async {
      final given = await service.createTransaction(userId, loan(TransactionType.loanGiven, 1000));
      expect(await balanceOf('account-1'), cashStart - 1000);

      await service.createTransaction(userId, repayment(given.id, 400));

      expect(await balanceOf('account-1'), cashStart - 600);
      final meta = LoanMetadata.fromJson(
        (await transactionDoc(given.id))['metadata'] as Map<String, dynamic>,
      );
      expect(meta.remainingAmount, 600);
      expect(meta.status, LoanStatus.partial);
    });

    test('repaying a loan you took subtracts money', () async {
      final taken = await service.createTransaction(userId, loan(TransactionType.loanTaken, 1000));
      expect(await balanceOf('account-1'), cashStart + 1000);

      await service.createTransaction(userId, repayment(taken.id, 1000));

      expect(await balanceOf('account-1'), cashStart);
      final meta = LoanMetadata.fromJson(
        (await transactionDoc(taken.id))['metadata'] as Map<String, dynamic>,
      );
      expect(meta.remainingAmount, 0);
      expect(meta.status, LoanStatus.completed);
    });

    test('over-repayment is rejected and nothing changes', () async {
      final given = await service.createTransaction(userId, loan(TransactionType.loanGiven, 100));
      await expectLater(
        service.createTransaction(userId, repayment(given.id, 150)),
        throwsA(isA<ValidationException>()),
      );
      expect(await balanceOf('account-1'), cashStart - 100);
    });

    test('deleting a repayment restores balance and remaining amount', () async {
      final given = await service.createTransaction(userId, loan(TransactionType.loanGiven, 1000));
      final paid = await service.createTransaction(userId, repayment(given.id, 1000));

      await service.deleteTransaction(userId, paid.id);

      expect(await balanceOf('account-1'), cashStart - 1000);
      final meta = LoanMetadata.fromJson(
        (await transactionDoc(given.id))['metadata'] as Map<String, dynamic>,
      );
      expect(meta.remainingAmount, 1000);
      expect(meta.status, LoanStatus.pending);
    });

    test('a loan with repayments cannot be deleted', () async {
      final given = await service.createTransaction(userId, loan(TransactionType.loanGiven, 1000));
      await service.createTransaction(userId, repayment(given.id, 100));

      await expectLater(
        service.deleteTransaction(userId, given.id),
        throwsA(isA<ValidationException>()),
      );
    });

    test('loan installments are stored as plain maps', () async {
      final due = DateTime(2030, 1, 1);
      final created = await service.createTransaction(
        userId,
        tx(
          TransactionType.loanGiven,
          200,
          categoryId: 'loan',
          metadata: LoanMetadata(
            originalAmount: 200,
            remainingAmount: 200,
            installments: [LoanInstallment(dueDate: due, amount: 200)],
          ).toJson(),
        ),
      );

      final stored = (await transactionDoc(created.id))['metadata'] as Map<String, dynamic>;
      expect(stored['installments'], isA<List<dynamic>>());
      expect((stored['installments'] as List<dynamic>).first, isA<Map<String, dynamic>>());
      expect(LoanMetadata.fromJson(stored).installments!.single.dueDate, due);
    });
  });

  group('update', () {
    test('changing the amount moves only the difference', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.expense, 100));
      await service.updateTransaction(userId, created.copyWith(amount: 250));
      expect(await balanceOf('account-1'), cashStart - 250);
    });

    test('changing the account moves the effect between accounts', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.income, 100));
      await service.updateTransaction(userId, created.copyWith(accountId: 'account-2'));
      expect(await balanceOf('account-1'), cashStart);
      expect(await balanceOf('account-2'), bankStart + 100);
    });

    test('changing type from expense to income flips the effect', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.expense, 100));
      await service.updateTransaction(userId, created.copyWith(type: TransactionType.income));
      expect(await balanceOf('account-1'), cashStart + 100);
    });

    test('uses the stored version, not a stale client copy', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.expense, 100));
      await service.updateTransaction(userId, created.copyWith(amount: 200));
      // Client still holds the original (amount 100) and edits to 300.
      await service.updateTransaction(userId, created.copyWith(amount: 300));
      expect(await balanceOf('account-1'), cashStart - 300);
    });

    test('transfers and loans cannot be edited', () async {
      final created = await service.createTransaction(userId, transfer(100));
      await expectLater(
        service.updateTransaction(userId, created.copyWith(amount: 50)),
        throwsA(isA<ValidationException>()),
      );
      expect(await balanceOf('account-1'), cashStart - 100);
    });
  });

  group('delete', () {
    test('reverts an expense and soft-deletes it', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.expense, 100));
      await service.deleteTransaction(userId, created.id);
      expect(await balanceOf('account-1'), cashStart);
      expect((await transactionDoc(created.id))['isDeleted'], true);
    });

    test('reverts both sides of a transfer', () async {
      final created = await service.createTransaction(userId, transfer(100));
      await service.deleteTransaction(userId, created.id);
      expect(await balanceOf('account-1'), cashStart);
      expect(await balanceOf('account-2'), bankStart);
    });

    test('deleting twice only reverts once', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.expense, 100));
      await service.deleteTransaction(userId, created.id);
      await service.deleteTransaction(userId, created.id);
      expect(await balanceOf('account-1'), cashStart);
    });
  });

  group('recalculateBalances', () {
    Future<void> addZeroOpeningAccount() => firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc('wallet')
        .set({
          'name': 'Wallet',
          'type': 'cash',
          'openingBalance': 0.0,
          'currentBalance': 0.0,
          'color': 0,
          'icon': 'x',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'createdBy': userId,
          'isDeleted': false,
        });

    test('opening 0, income then smaller expense stays positive', () async {
      await addZeroOpeningAccount();
      await service.createTransaction(userId, tx(TransactionType.income, 1000, accountId: 'wallet'));
      await service.createTransaction(userId, tx(TransactionType.expense, 400, accountId: 'wallet'));
      expect(await balanceOf('wallet'), 600);
    });

    test('repairs a balance corrupted by an old stale write', () async {
      await addZeroOpeningAccount();
      await service.createTransaction(userId, tx(TransactionType.income, 1000, accountId: 'wallet'));
      // Old app versions could write back a stale balance of 0 here.
      await firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('wallet')
          .update({'currentBalance': 0.0});
      await service.createTransaction(userId, tx(TransactionType.expense, 400, accountId: 'wallet'));
      expect(await balanceOf('wallet'), -400);

      final result = await service.recalculateBalances(userId);

      expect(await balanceOf('wallet'), 600);
      expect(result.corrections.map((c) => c.accountId), contains('wallet'));
    });

    test('matches live writes for every type and leaves correct balances alone', () async {
      final given = await service.createTransaction(userId, loan(TransactionType.loanGiven, 1000));
      await service.createTransaction(userId, repayment(given.id, 300));
      await service.createTransaction(userId, loan(TransactionType.loanTaken, 200));
      await service.createTransaction(userId, transfer(50));
      final deleted = await service.createTransaction(userId, tx(TransactionType.expense, 70));
      await service.deleteTransaction(userId, deleted.id);

      final cash = await balanceOf('account-1');
      final bank = await balanceOf('account-2');

      // The seeded transaction-1 (expense 500) is part of the history, so the
      // seeded balances themselves are out of sync by 500; compare deltas.
      final result = await service.recalculateBalances(userId);
      final cashFix = result.corrections.where((c) => c.accountId == 'account-1');
      expect(cashFix.single.correctedBalance, cash - 500);
      expect(result.corrections.where((c) => c.accountId == 'account-2'), isEmpty);
      expect(await balanceOf('account-2'), bank);
      expect(result.skipped, 0);
    });
  });

  group('transfers that lost their destination', () {
    Future<String> brokenTransfer(double amount) async {
      final created = await service.createTransaction(userId, transfer(amount));
      // What the old edit form did: rewrote the record without metadata.
      await firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(created.id)
          .update({'metadata': null});
      return created.id;
    }

    test('are reported by the sync instead of being silently skipped', () async {
      final id = await brokenTransfer(100);
      final result = await service.recalculateBalances(userId);
      expect(result.brokenTransfers.map((t) => t.id), [id]);
      expect(result.skipped, 0);
    });

    test('repairing the destination credits the target on the next sync', () async {
      final id = await brokenTransfer(100);
      // Target lost its credit (as reported: source reduced, target not).
      await firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .doc('account-2')
          .update({'currentBalance': bankStart});

      await service.setTransferDestination(userId, id, 'account-2');
      final result = await service.recalculateBalances(userId);

      expect(result.brokenTransfers, isEmpty);
      expect(await balanceOf('account-2'), bankStart + 100);
      final stored = (await transactionDoc(id))['metadata'] as Map<String, dynamic>;
      expect(stored['fromAccountId'], 'account-1');
      expect(stored['toAccountId'], 'account-2');
    });

    test('destination cannot be the source account', () async {
      final id = await brokenTransfer(100);
      await expectLater(
        service.setTransferDestination(userId, id, 'account-1'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('updateAttachments', () {
    test('has no effect on balances for an editable transaction', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.expense, 200));
      final before = await balanceOf('account-1');

      await service.updateAttachments(userId, created.id, ['https://example.com/receipt.pdf']);

      expect(await balanceOf('account-1'), before);
      final stored = await transactionDoc(created.id);
      expect(stored['attachments'], ['https://example.com/receipt.pdf']);
    });

    test('works on a transfer even though transfers cannot be edited', () async {
      final created = await service.createTransaction(userId, transfer(500));
      final sourceBefore = await balanceOf('account-1');
      final destBefore = await balanceOf('account-2');

      await service.updateAttachments(userId, created.id, ['https://example.com/receipt.pdf']);

      expect(await balanceOf('account-1'), sourceBefore);
      expect(await balanceOf('account-2'), destBefore);
    });

    test('an empty list clears the field instead of storing []', () async {
      final created = await service.createTransaction(userId, tx(TransactionType.expense, 200));
      await service.updateAttachments(userId, created.id, ['https://example.com/a.pdf']);
      await service.updateAttachments(userId, created.id, []);

      final stored = await transactionDoc(created.id);
      expect(stored['attachments'], isNull);
    });

    test('throws for a transaction that does not exist', () async {
      await expectLater(
        service.updateAttachments(userId, 'missing-id', ['https://example.com/a.pdf']),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
