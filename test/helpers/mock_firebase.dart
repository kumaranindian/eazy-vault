import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

export 'package:fake_cloud_firestore/fake_cloud_firestore.dart'
    show FakeFirebaseFirestore;


class MockFirebase {
  static FakeFirebaseFirestore getFakeFirestore() {
    return FakeFirebaseFirestore();
  }

  static MockFirebaseAuth getMockAuth({
    bool signedIn = true,
    String uid = 'test-user-id',
    String email = 'test@example.com',
    String displayName = 'Test User',
  }) {
    final user = MockUser(
      uid: uid,
      email: email,
      displayName: displayName,
      isAnonymous: false,
    );

    return MockFirebaseAuth(
      signedIn: signedIn,
      mockUser: user,
    );
  }

  static Future<void> seedFirestore(
    FakeFirebaseFirestore firestore,
    String userId,
  ) async {
    // Seed accounts
    await firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc('account-1')
        .set({
      'name': 'Cash',
      'type': 'cash',
      'currentBalance': 10000.0,
      'openingBalance': 10000.0,
      'color': 0xFF4CAF50,
      'icon': '💵',
      'isActive': true,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'createdBy': userId,
      'isDeleted': false,
    });

    await firestore
        .collection('users')
        .doc(userId)
        .collection('accounts')
        .doc('account-2')
        .set({
      'name': 'Bank',
      'type': 'savings',
      'currentBalance': 50000.0,
      'openingBalance': 50000.0,
      'color': 0xFF2196F3,
      'icon': '🏦',
      'isActive': true,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'createdBy': userId,
      'isDeleted': false,
    });

    // Seed categories
    await firestore
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc('category-1')
        .set({
      'name': 'Food & Dining',
      'type': 'expense',
      'isDefault': false,
      'color': 0xFFFF5722,
      'icon': '🍔',
      'isActive': true,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'createdBy': userId,
      'isDeleted': false,
    });

    await firestore
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc('category-2')
        .set({
      'name': 'Salary',
      'type': 'income',
      'isDefault': false,
      'color': 0xFF4CAF50,
      'icon': '💰',
      'isActive': true,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'createdBy': userId,
      'isDeleted': false,
    });

    // Seed transactions
    await firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc('transaction-1')
        .set({
      'type': 'expense',
      'amount': 500.0,
      'accountId': 'account-1',
      'categoryId': 'category-1',
      'date': Timestamp.now(),
      'description': 'Lunch at restaurant',
      'vendor': 'Restaurant ABC',
      'attachments': null,
      'metadata': null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'createdBy': userId,
      'isDeleted': false,
    });
  }
}
