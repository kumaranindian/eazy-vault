import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/services/transfer_service.dart';
import 'transactions_providers.dart';

part 'transfer_providers.g.dart';

@Riverpod(keepAlive: true)
TransferService transferService(TransferServiceRef ref) {
  return TransferService(
    balanceService: ref.watch(accountBalanceServiceProvider),
  );
}
