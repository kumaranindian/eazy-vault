import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/services/logger_service.dart';
import '../models/account_model.dart';

abstract class AccountsRemoteDataSource {
  Future<List<AccountModel>> getAccounts(String userId);
  Future<AccountModel> getAccount(String userId, String accountId);
  Future<AccountModel> createAccount(String userId, AccountModel account);
  Future<AccountModel> updateAccount(String userId, AccountModel account);
  Future<void> deleteAccount(String userId, String accountId);
  Stream<List<AccountModel>> watchAccounts(String userId);
}

class AccountsRemoteDataSourceImpl implements AccountsRemoteDataSource {
  AccountsRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _accountsCollection(String userId) {
    return _firestore
        .collection(AppConstants.userCollection)
        .doc(userId)
        .collection(AppConstants.accountsCollection);
  }

  @override
  Future<List<AccountModel>> getAccounts(String userId) async {
    try {
      LoggerService.info('Fetching accounts for user: $userId');

      final querySnapshot = await _accountsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .orderBy(AppConstants.createdAtField, descending: true)
          .get();

      final accounts = querySnapshot.docs
          .map((doc) => AccountModel.fromFirestore(doc))
          .toList();

      LoggerService.info('Fetched ${accounts.length} accounts');
      return accounts;
    } catch (e, stackTrace) {
      LoggerService.error('Get accounts error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to fetch accounts: ${e.toString()}');
    }
  }

  @override
  Future<AccountModel> getAccount(String userId, String accountId) async {
    try {
      LoggerService.info('Fetching account: $accountId');

      final doc = await _accountsCollection(userId).doc(accountId).get();

      if (!doc.exists) {
        throw const NotFoundException('Account not found');
      }

      final account = AccountModel.fromFirestore(doc);
      if (account.isDeleted) {
        throw const NotFoundException('Account not found');
      }

      return account;
    } catch (e, stackTrace) {
      LoggerService.error('Get account error', error: e, stackTrace: stackTrace);
      if (e is NotFoundException) rethrow;
      throw ServerException('Failed to fetch account: ${e.toString()}');
    }
  }

  @override
  Future<AccountModel> createAccount(String userId, AccountModel account) async {
    try {
      LoggerService.info('Creating account: ${account.name}');

      final docRef = _accountsCollection(userId).doc();
      final accountWithId = account.copyWith(id: docRef.id);

      await docRef.set(accountWithId.toFirestore());

      LoggerService.info('Account created: ${docRef.id}');
      return accountWithId;
    } catch (e, stackTrace) {
      LoggerService.error('Create account error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to create account: ${e.toString()}');
    }
  }

  /// Updates the editable account fields.
  ///
  /// `currentBalance` is never taken from [account] (the client copy may be
  /// stale). A change of `openingBalance` is applied to the stored
  /// `currentBalance` as a difference, inside a Firestore transaction.
  @override
  Future<AccountModel> updateAccount(String userId, AccountModel account) async {
    try {
      LoggerService.info('Updating account: ${account.id}');

      final docRef = _accountsCollection(userId).doc(account.id);
      late AccountModel updatedAccount;

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw const NotFoundException('Account not found');
        }
        final stored = AccountModel.fromFirestore(doc);
        if (stored.isDeleted) {
          throw const NotFoundException('Account not found');
        }

        final openingDelta = account.openingBalance - stored.openingBalance;
        updatedAccount = stored.copyWith(
          name: account.name,
          type: account.type,
          openingBalance: account.openingBalance,
          currentBalance: stored.currentBalance + openingDelta,
          color: account.color,
          icon: account.icon,
          isActive: account.isActive,
          description: account.description,
          updatedAt: DateTime.now(),
        );

        transaction.update(docRef, {
          'name': updatedAccount.name,
          'type': updatedAccount.type.name,
          'openingBalance': updatedAccount.openingBalance,
          'currentBalance': updatedAccount.currentBalance,
          'color': updatedAccount.color,
          'icon': updatedAccount.icon,
          'isActive': updatedAccount.isActive,
          'description': updatedAccount.description,
          AppConstants.updatedAtField: Timestamp.fromDate(updatedAccount.updatedAt),
        });
      });

      LoggerService.info('Account updated: ${account.id}');
      return updatedAccount;
    } catch (e, stackTrace) {
      LoggerService.error('Update account error', error: e, stackTrace: stackTrace);
      if (e is AppException) rethrow;
      throw ServerException('Failed to update account: ${e.toString()}');
    }
  }

  /// Soft-deletes an account. Accounts that still have (non-deleted)
  /// transactions, including incoming transfers, can't be deleted so no
  /// transaction is left pointing at a deleted account.
  @override
  Future<void> deleteAccount(String userId, String accountId) async {
    try {
      LoggerService.info('Deleting account: $accountId');

      final transactions = _firestore
          .collection(AppConstants.userCollection)
          .doc(userId)
          .collection(AppConstants.transactionsCollection);

      final direct = await transactions
          .where('accountId', isEqualTo: accountId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .limit(1)
          .get();
      final incomingTransfers = await transactions
          .where('metadata.toAccountId', isEqualTo: accountId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .limit(1)
          .get();

      if (direct.docs.isNotEmpty || incomingTransfers.docs.isNotEmpty) {
        throw const ValidationException(
          'This account has transactions. Delete them first or mark the account inactive.',
        );
      }

      await _accountsCollection(userId).doc(accountId).update({
        AppConstants.isDeletedField: true,
        AppConstants.updatedAtField: Timestamp.now(),
      });

      LoggerService.info('Account deleted: $accountId');
    } catch (e, stackTrace) {
      LoggerService.error('Delete account error', error: e, stackTrace: stackTrace);
      if (e is AppException) rethrow;
      throw ServerException('Failed to delete account: ${e.toString()}');
    }
  }

  @override
  Stream<List<AccountModel>> watchAccounts(String userId) {
    try {
      LoggerService.info('Watching accounts for user: $userId');

      return _accountsCollection(userId)
          .where(AppConstants.isDeletedField, isEqualTo: false)
          .orderBy(AppConstants.createdAtField, descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => AccountModel.fromFirestore(doc))
            .toList();
      });
    } catch (e, stackTrace) {
      LoggerService.error('Watch accounts error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to watch accounts: ${e.toString()}');
    }
  }
}
