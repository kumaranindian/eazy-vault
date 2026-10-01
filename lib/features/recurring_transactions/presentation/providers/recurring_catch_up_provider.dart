import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../transactions/presentation/providers/financial_refresh.dart';
import 'recurring_transactions_notifier.dart';
import 'recurring_transactions_providers.dart';

part 'recurring_catch_up_provider.g.dart';

/// Runs once per app session (kept alive): generates any transactions every
/// active recurring rule owes, then invalidates the providers that show
/// balances/totals since the writes happen outside `TransactionsNotifier`.
/// Returns how many transactions were created, so the UI can tell the user.
@Riverpod(keepAlive: true)
Future<int> recurringTransactionsCatchUp(RecurringTransactionsCatchUpRef ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return 0;
  }

  final service = ref.read(recurringTransactionServiceProvider);
  final generatedCount = await service.catchUpAll(user.uid);

  if (generatedCount > 0) {
    refreshFinancialData(ref.invalidate);
    ref.invalidate(recurringTransactionsNotifierProvider);
  }

  return generatedCount;
}
