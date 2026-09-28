import 'package:eazyvault/features/authentication/presentation/providers/auth_providers.dart';
import 'package:eazyvault/features/transactions/presentation/widgets/transfer_transaction_form.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firebase.dart';
import '../helpers/test_helpers.dart';

/// Drives the real transfer form (UI → provider → service → Firestore) and
/// checks both account balances.
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

  testWidgets('transfer debits the source and credits the target', (tester) async {
    final firestore = MockFirebase.getFakeFirestore();
    await tester.runAsync(() => MockFirebase.seedFirestore(firestore, userId));
    var succeeded = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseFirestoreProvider.overrideWithValue(firestore),
          currentUserProvider.overrideWith(
            (ref) => MockUser(uid: userId, email: 'test@example.com'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TransferTransactionForm(onSuccess: () => succeeded = true),
            ),
          ),
        ),
      ),
    );

    // Let the accounts list load from Firestore.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    Future<void> pick(String field, String accountName) async {
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, field));
      await tester.pumpAndSettle();
      await tester.tap(find.text(accountName).last);
      await tester.pumpAndSettle();
    }

    await pick('From Account', 'Cash');
    await pick('To Account', 'Bank');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250');
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();

    expect(succeeded, isTrue, reason: 'form should report success');
    final cash = await tester.runAsync(() => balanceOf(firestore, 'account-1'));
    final bank = await tester.runAsync(() => balanceOf(firestore, 'account-2'));
    expect(cash, 10000 - 250);
    expect(bank, 50000 + 250);
  });
}
