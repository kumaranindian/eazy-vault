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

  Future<Failure?> createAccount(AccountModel account) {
    return _mutate((userId) async {
      final result = await ref
          .read(accountsRepositoryProvider)
          .createAccount(userId, account);
      return result.failure;
    });
  }

  Future<Failure?> updateAccount(AccountModel account) {
    return _mutate((userId) async {
      final result = await ref
          .read(accountsRepositoryProvider)
          .updateAccount(userId, account);
      return result.failure;
    });
  }

  Future<Failure?> deleteAccount(String accountId) {
    return _mutate((userId) async {
      return ref
          .read(accountsRepositoryProvider)
          .deleteAccount(userId, accountId);
    });
  }

  /// Runs a write and reloads the list on success. Returns `null` on success,
  /// otherwise the [Failure]; the list state is left untouched on failure.
  Future<Failure?> _mutate(
    Future<Failure?> Function(String userId) operation,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return const Failure.authenticationError('User not authenticated');
    }

    final link = ref.keepAlive();
    try {
      final failure = await operation(user.uid);
      if (failure != null) return failure;
      ref.invalidate(accountProvider);

      await _loadAccounts();
      return null;
    } finally {
      link.close();
    }
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
