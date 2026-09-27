import '../../../../core/models/failure.dart';
import '../../data/models/account_model.dart';

abstract class AccountsRepository {
  Future<({List<AccountModel> accounts, Failure? failure})> getAccounts(String userId);
  
  Future<({AccountModel? account, Failure? failure})> getAccount(
    String userId,
    String accountId,
  );
  
  Future<({AccountModel? account, Failure? failure})> createAccount(
    String userId,
    AccountModel account,
  );
  
  Future<({AccountModel? account, Failure? failure})> updateAccount(
    String userId,
    AccountModel account,
  );
  
  Future<Failure?> deleteAccount(String userId, String accountId);
  
  Stream<List<AccountModel>> watchAccounts(String userId);
}
