import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/accounts_remote_datasource.dart';
import '../../data/repositories/accounts_repository_impl.dart';
import '../../domain/repositories/accounts_repository.dart';

part 'accounts_providers.g.dart';

@Riverpod(keepAlive: true)
AccountsRemoteDataSource accountsRemoteDataSource(
  AccountsRemoteDataSourceRef ref,
) {
  return AccountsRemoteDataSourceImpl(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
}

@Riverpod(keepAlive: true)
AccountsRepository accountsRepository(AccountsRepositoryRef ref) {
  return AccountsRepositoryImpl(
    remoteDataSource: ref.watch(accountsRemoteDataSourceProvider),
  );
}
