import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/transactions_remote_datasource.dart';
import '../../data/repositories/transactions_repository_impl.dart';
import '../../domain/repositories/transactions_repository.dart';
import '../../domain/services/account_balance_service.dart';
import '../../domain/services/attachment_upload_service.dart';
import '../../domain/services/transaction_export_service.dart';

part 'transactions_providers.g.dart';

@Riverpod(keepAlive: true)
TransactionsRemoteDataSource transactionsRemoteDataSource(
  TransactionsRemoteDataSourceRef ref,
) {
  return TransactionsRemoteDataSourceImpl(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
}

@Riverpod(keepAlive: true)
AccountBalanceService accountBalanceService(AccountBalanceServiceRef ref) {
  return AccountBalanceService(
    firestore: ref.watch(firebaseFirestoreProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionsRepository transactionsRepository(TransactionsRepositoryRef ref) {
  return TransactionsRepositoryImpl(
    remoteDataSource: ref.watch(transactionsRemoteDataSourceProvider),
    balanceService: ref.watch(accountBalanceServiceProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionExportService transactionExportService(TransactionExportServiceRef ref) {
  return const TransactionExportService();
}

@Riverpod(keepAlive: true)
AttachmentUploadService attachmentUploadService(AttachmentUploadServiceRef ref) {
  return AttachmentUploadService(storage: ref.watch(firebaseStorageProvider));
}
