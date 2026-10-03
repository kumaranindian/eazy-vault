import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../domain/services/csv_import_service.dart';

part 'csv_import_providers.g.dart';

@Riverpod(keepAlive: true)
CsvImportService csvImportService(CsvImportServiceRef ref) {
  return CsvImportService(
    transactionsRepository: ref.watch(transactionsRepositoryProvider),
  );
}
