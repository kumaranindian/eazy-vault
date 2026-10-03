import 'package:eazyvault/features/authentication/presentation/providers/auth_providers.dart';
import 'package:eazyvault/features/recurring_transactions/data/models/recurring_transaction_model.dart';
import 'package:eazyvault/features/recurring_transactions/domain/enums/recurrence_frequency.dart';
import 'package:eazyvault/features/recurring_transactions/presentation/providers/recurring_transactions_notifier.dart';
import 'package:eazyvault/features/transactions/domain/enums/transaction_type.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

/// Rule creation should catch up overdue occurrences immediately (Phase 1
/// Feature 4) instead of waiting for the next app session's catch-up pass.
void main() {
  const userId = TestHelpers.testUserId;

  Future<double> balanceOf(FakeFirebaseFirestore firestore, String id) async {
    final doc = await firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc(id)
        .get();
    return (doc.data()!['currentBalance'] as num).toDouble();
  }

  test('creating a rule with a past start date generates missed occurrences right away', () async {
    final firestore = MockFirebase.getFakeFirestore();
    await MockFirebase.seedFirestore(firestore, userId);
    final startingBalance = await balanceOf(firestore, 'account-1');

    final container = ProviderContainer(overrides: [
      firebaseFirestoreProvider.overrideWithValue(firestore),
      currentUserProvider.overrideWith(
        (ref) => MockUser(uid: userId, email: 'test@example.com'),
      ),
    ]);
    addTearDown(container.dispose);

    final now = DateTime.now();
    final rule = RecurringTransactionModel(
      id: '',
      type: TransactionType.expense,
      amount: 100,
      accountId: 'account-1',
      categoryId: 'category-1',
      frequency: RecurrenceFrequency.daily,
      startDate: now.subtract(const Duration(days: 3)),
      isActive: true,
      createdAt: now,
      updatedAt: now,
      createdBy: userId,
    );

    final result = await container
        .read(recurringTransactionsNotifierProvider.notifier)
        .createRule(rule);

    expect(result.failure, isNull);
    // Due on day -3, -2, -1 and today: 4 occurrences.
    expect(result.generatedCount, 4);

    final balanceAfter = await balanceOf(firestore, 'account-1');
    expect(balanceAfter, startingBalance - 4 * 100);
  });
}
