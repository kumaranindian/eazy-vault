import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/models/failure.dart';
import '../../../../core/services/logger_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/account_model.dart';
import 'accounts_providers.dart';

part 'accounts_notifier.freezed.dart';
part 'accounts_notifier.g.dart';

@freezed
class AccountsState with _$AccountsState {
  const factory AccountsState.initial() = _Initial;
  const factory AccountsState.loading() = _Loading;
  const factory AccountsState.loaded(List<AccountModel> accounts) = _Loaded;
  const factory AccountsState.error(Failure failure) = _Error;
}

@riverpod
class AccountsNotifier extends _$AccountsNotifier {
  @override
  AccountsState build() {
    _loadAccounts();
    return const AccountsState.initial();
  }

  Future<void> _loadAccounts() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AccountsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return;
    }

    state = const AccountsState.loading();

    final repository = ref.read(accountsRepositoryProvider);
    final result = await repository.getAccounts(user.uid);

    if (result.failure != null) {
      state = AccountsState.error(result.failure!);
    } else {
      state = AccountsState.loaded(result.accounts);
    }
  }

  Future<bool> createAccount(AccountModel account) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AccountsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return false;
    }

    final repository = ref.read(accountsRepositoryProvider);
    final result = await repository.createAccount(user.uid, account);

    if (result.failure != null) {
      state = AccountsState.error(result.failure!);
      return false;
    }

    await _loadAccounts();
    return true;
  }

  Future<bool> updateAccount(AccountModel account) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AccountsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return false;
    }

    final repository = ref.read(accountsRepositoryProvider);
    final result = await repository.updateAccount(user.uid, account);

    if (result.failure != null) {
      state = AccountsState.error(result.failure!);
      return false;
    }

    await _loadAccounts();
    return true;
  }

  Future<bool> deleteAccount(String accountId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AccountsState.error(
        Failure.authenticationError('User not authenticated'),
      );
      return false;
    }

    final repository = ref.read(accountsRepositoryProvider);
    final failure = await repository.deleteAccount(user.uid, accountId);

    if (failure != null) {
      state = AccountsState.error(failure);
      return false;
    }

    await _loadAccounts();
    return true;
  }

  void refresh() {
    _loadAccounts();
  }
}

@riverpod
Stream<List<AccountModel>> accountsStream(AccountsStreamRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(accountsRepositoryProvider);
  return repository.watchAccounts(user.uid);
}

@riverpod
Future<AccountModel?> account(AccountRef ref, String accountId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    LoggerService.warning('User not authenticated');
    return null;
  }

  final repository = ref.watch(accountsRepositoryProvider);
  final result = await repository.getAccount(user.uid, accountId);

  if (result.failure != null) {
    LoggerService.error('Failed to fetch account', error: result.failure);
    return null;
  }

  return result.account;
}

@riverpod
double totalBalance(TotalBalanceRef ref) {
  final accountsState = ref.watch(accountsNotifierProvider);

  return accountsState.maybeWhen(
    loaded: (accounts) => accounts.fold<double>(
      0,
      (sum, account) => sum + account.currentBalance,
    ),
    orElse: () => 0,
  );
}
