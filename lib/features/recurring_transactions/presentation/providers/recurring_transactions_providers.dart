import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../data/datasources/recurring_transactions_remote_datasource.dart';
import '../../data/repositories/recurring_transactions_repository_impl.dart';
import '../../domain/repositories/recurring_transactions_repository.dart';
import '../../domain/services/recurring_transaction_service.dart';

part 'recurring_transactions_providers.g.dart';

@Riverpod(keepAlive: true)
RecurringTransactionsRemoteDataSource recurringTransactionsRemoteDataSource(
  RecurringTransactionsRemoteDataSourceRef ref,
) {
  return RecurringTransactionsRemoteDataSourceImpl(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
}

@Riverpod(keepAlive: true)
RecurringTransactionsRepository recurringTransactionsRepository(
  RecurringTransactionsRepositoryRef ref,
) {
  return RecurringTransactionsRepositoryImpl(
    remoteDataSource: ref.watch(recurringTransactionsRemoteDataSourceProvider),
  );
}

@Riverpod(keepAlive: true)
RecurringTransactionService recurringTransactionService(RecurringTransactionServiceRef ref) {
  return RecurringTransactionService(
    recurringRepository: ref.watch(recurringTransactionsRepositoryProvider),
    transactionsRepository: ref.watch(transactionsRepositoryProvider),
  );
}
