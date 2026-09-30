import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../datasources/accounts_remote_datasource.dart';
import '../models/account_model.dart';
import '../../../../core/utils/error_messages.dart';

class AccountsRepositoryImpl implements AccountsRepository {
  AccountsRepositoryImpl({required AccountsRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final AccountsRemoteDataSource _remoteDataSource;

  @override
  Future<({List<AccountModel> accounts, Failure? failure})> getAccounts(
    String userId,
  ) async {
    try {
      final accounts = await _remoteDataSource.getAccounts(userId);
      return (accounts: accounts, failure: null);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (accounts: <AccountModel>[], failure: Failure.serverError(e.message));
    } on NetworkException catch (e) {
      LoggerService.error('Network error', error: e);
      return (accounts: <AccountModel>[], failure: Failure.networkError(e.message));
    } catch (e) {
      LoggerService.error('Unknown error', error: e);
      return (accounts: <AccountModel>[], failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({AccountModel? account, Failure? failure})> getAccount(
    String userId,
    String accountId,
  ) async {
    try {
      final account = await _remoteDataSource.getAccount(userId, accountId);
      return (account: account, failure: null);
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return (account: null, failure: Failure.notFoundError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (account: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (account: null, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({AccountModel? account, Failure? failure})> createAccount(
    String userId,
    AccountModel account,
  ) async {
    try {
      final createdAccount = await _remoteDataSource.createAccount(userId, account);
      return (account: createdAccount, failure: null);
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (account: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (account: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (account: null, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<({AccountModel? account, Failure? failure})> updateAccount(
    String userId,
    AccountModel account,
  ) async {
    try {
      final updatedAccount = await _remoteDataSource.updateAccount(userId, account);
      return (account: updatedAccount, failure: null);
    } on NotFoundException catch (e) {
      LoggerService.error('Not found error', error: e);
      return (account: null, failure: Failure.notFoundError(e.message));
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return (account: null, failure: Failure.validationError(e.message));
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return (account: null, failure: Failure.serverError(e.message));
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return (account: null, failure: Failure.unknownError(ErrorMessages.from(e)));
    }
  }

  @override
  Future<Failure?> deleteAccount(String userId, String accountId) async {
    try {
      await _remoteDataSource.deleteAccount(userId, accountId);
      return null;
    } on ValidationException catch (e) {
      LoggerService.error('Validation error', error: e);
      return Failure.validationError(e.message);
    } on ServerException catch (e) {
      LoggerService.error('Server error', error: e);
      return Failure.serverError(e.message);
    } catch (e, stackTrace) {
      LoggerService.error('Unknown error', error: e, stackTrace: stackTrace);
      return Failure.unknownError(ErrorMessages.from(e));
    }
  }

  @override
  Stream<List<AccountModel>> watchAccounts(String userId) {
    return _remoteDataSource.watchAccounts(userId);
  }
}
