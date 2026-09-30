import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/budgets_remote_datasource.dart';
import '../../data/repositories/budgets_repository_impl.dart';
import '../../domain/repositories/budgets_repository.dart';

part 'budgets_providers.g.dart';

@Riverpod(keepAlive: true)
BudgetsRemoteDataSource budgetsRemoteDataSource(BudgetsRemoteDataSourceRef ref) {
  return BudgetsRemoteDataSourceImpl(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
}

@Riverpod(keepAlive: true)
BudgetsRepository budgetsRepository(BudgetsRepositoryRef ref) {
  return BudgetsRepositoryImpl(
    remoteDataSource: ref.watch(budgetsRemoteDataSourceProvider),
  );
}
