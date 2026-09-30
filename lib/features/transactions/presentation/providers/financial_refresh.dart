import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/presentation/providers/accounts_notifier.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../dashboard/presentation/providers/spending_trends_provider.dart';
import 'loan_providers.dart';

/// Invalidates every provider that shows balances, monthly totals or loan
/// data. Call after any write that moves money (transaction create/update/
/// delete, transfer, loan, repayment, account edit).
///
/// Pass `ref.invalidate` from either a `Ref` or a `WidgetRef`.
void refreshFinancialData(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(accountsNotifierProvider);
  invalidate(accountProvider);
  invalidate(currentMonthStatsProvider);
  invalidate(accountFinancialsProvider);
  invalidate(last6MonthsStatsProvider);
  invalidate(activeLoansProvider);
  invalidate(overdueLoansProvider);
  invalidate(totalOwedToYouProvider);
  invalidate(totalYouOweProvider);
}
