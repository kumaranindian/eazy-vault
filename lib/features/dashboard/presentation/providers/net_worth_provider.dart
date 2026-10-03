import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../domain/models/net_worth_point.dart';
import '../../domain/services/net_worth_service.dart';

part 'net_worth_provider.g.dart';

@Riverpod(keepAlive: true)
NetWorthService netWorthService(NetWorthServiceRef ref) {
  return NetWorthService(
    accountsRepository: ref.watch(accountsRepositoryProvider),
    transactionsRepository: ref.watch(transactionsRepositoryProvider),
  );
}

@riverpod
Future<List<NetWorthPoint>> netWorthHistory(
  NetWorthHistoryRef ref, {
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final service = ref.watch(netWorthServiceProvider);
  return service.computeHistory(user.uid, startDate: startDate, endDate: endDate);
}
