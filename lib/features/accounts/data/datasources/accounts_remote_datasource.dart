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

      return AccountModel.fromFirestore(doc);
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

  @override
  Future<AccountModel> updateAccount(String userId, AccountModel account) async {
    try {
      LoggerService.info('Updating account: ${account.id}');

      final updatedAccount = account.copyWith(updatedAt: DateTime.now());

      await _accountsCollection(userId)
          .doc(account.id)
          .update(updatedAccount.toFirestore());

      LoggerService.info('Account updated: ${account.id}');
      return updatedAccount;
    } catch (e, stackTrace) {
      LoggerService.error('Update account error', error: e, stackTrace: stackTrace);
      throw ServerException('Failed to update account: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAccount(String userId, String accountId) async {
    try {
      LoggerService.info('Deleting account: $accountId');

      await _accountsCollection(userId).doc(accountId).update({
        AppConstants.isDeletedField: true,
        AppConstants.updatedAtField: Timestamp.now(),
      });

      LoggerService.info('Account deleted: $accountId');
    } catch (e, stackTrace) {
      LoggerService.error('Delete account error', error: e, stackTrace: stackTrace);
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
