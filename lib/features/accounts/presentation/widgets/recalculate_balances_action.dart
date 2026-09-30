import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../transactions/domain/services/account_balance_service.dart';
import '../../../transactions/presentation/providers/financial_refresh.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../data/models/account_model.dart';
import '../providers/accounts_notifier.dart';

/// Sync button used on the dashboard and account screens.
class SyncBalancesButton extends ConsumerWidget {
  const SyncBalancesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.sync),
      tooltip: 'Sync balances',
      onPressed: () => recalculateBalancesWithConfirmation(context, ref),
    );
  }
}

/// Asks for confirmation, rebuilds every account balance from its opening
/// balance and transactions, then shows what changed. Transfers that lost
/// their destination account can be repaired from the result dialog.
Future<void> recalculateBalancesWithConfirmation(
  BuildContext context,
  WidgetRef ref,
) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final confirmed = await ConfirmationDialog.show(
    context,
    title: 'Sync balances',
    message:
        'Every account balance will be rebuilt from its opening balance and '
        'all its transactions (income, expenses, transfers, loans). Use this '
        'if a balance looks wrong.',
    confirmText: 'Sync',
  );
  if (!confirmed || !context.mounted) return;

  final service = ref.read(accountBalanceServiceProvider);
  // showDialog pushes onto the root navigator; pop the progress dialog there.
  final navigator = Navigator.of(context, rootNavigator: true);
  // Blocks the UI (and repeat taps) while every transaction is re-read.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Syncing balances...')),
            ],
          ),
        ),
      ),
    ),
  );

  BalanceRecalculation? result;
  String? error;
  try {
    result = await service.recalculateBalances(user.uid);
    refreshFinancialData(ref.invalidate);
  } catch (e, st) {
    LoggerService.error('Sync balances failed', error: e, stackTrace: st);
    error = ErrorMessages.from(e, action: 'sync balances');
  } finally {
    navigator.pop();
  }

  if (!context.mounted) return;
  if (result == null) {
    context.showErrorSnackBar(error);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _SyncResultDialog(userId: user.uid, initialResult: result!),
  );
}

class _SyncResultDialog extends ConsumerStatefulWidget {
  const _SyncResultDialog({required this.userId, required this.initialResult});

  final String userId;
  final BalanceRecalculation initialResult;

  @override
  ConsumerState<_SyncResultDialog> createState() => _SyncResultDialogState();
}

class _SyncResultDialogState extends ConsumerState<_SyncResultDialog> {
  late BalanceRecalculation _result = widget.initialResult;

  /// Corrections from every sync run in this dialog, latest value per account.
  late final Map<String, BalanceCorrection> _allCorrections = {
    for (final c in widget.initialResult.corrections) c.accountId: c,
  };
  String? _repairingId;

  Future<void> _repair(String transactionId, String toAccountId) async {
    setState(() => _repairingId = transactionId);
    final service = ref.read(accountBalanceServiceProvider);
    try {
      await service.setTransferDestination(widget.userId, transactionId, toAccountId);
      final result = await service.recalculateBalances(widget.userId);
      refreshFinancialData(ref.invalidate);
      if (!mounted) return;
      setState(() {
        _result = result;
        for (final c in result.corrections) {
          final previous = _allCorrections[c.accountId];
          _allCorrections[c.accountId] = BalanceCorrection(
            accountId: c.accountId,
            accountName: c.accountName,
            previousBalance: previous?.previousBalance ?? c.previousBalance,
            correctedBalance: c.correctedBalance,
          );
        }
      });
    } catch (e, st) {
      LoggerService.error('Repair transfer failed', error: e, stackTrace: st);
      if (mounted) {
        context.showErrorSnackBar(ErrorMessages.from(e, action: 'repair the transfer'));
      }
    } finally {
      if (mounted) setState(() => _repairingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsNotifierProvider).maybeWhen<List<AccountModel>>(
          loaded: (accounts) => accounts,
          orElse: () => <AccountModel>[],
        );
    final accountNames = {for (final a in accounts) a.id: a.name};

    return AlertDialog(
      title: const Text('Balances synced'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_allCorrections.isEmpty)
                const Text('All balances were already correct.')
              else
                for (final correction in _allCorrections.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${correction.accountName}: '
                      '${correction.previousBalance.toCurrency()} → '
                      '${correction.correctedBalance.toCurrency()}',
                    ),
                  ),
              if (_result.brokenTransfers.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Transfers missing their destination account',
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'An older version of the app lost the target account of '
                  'these transfers, so they are left out of all balances. '
                  'Choose where the money went to include them.',
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final transfer in _result.brokenTransfers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${transfer.date.toFormattedDate()} · '
                          '${transfer.amount.toCurrency()} from '
                          '${accountNames[transfer.metadata?['fromAccountId'] ?? transfer.accountId] ?? 'unknown account'}'
                          '${transfer.description == null ? '' : ' · ${transfer.description}'}',
                        ),
                        const SizedBox(height: 4),
                        if (_repairingId == transfer.id)
                          const LinearProgressIndicator()
                        else
                          DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Choose destination account'),
                            items: [
                              for (final account in accounts)
                                if (account.id !=
                                    (transfer.metadata?['fromAccountId'] ?? transfer.accountId))
                                  DropdownMenuItem(
                                    value: account.id,
                                    child: Text(account.name, overflow: TextOverflow.ellipsis),
                                  ),
                            ],
                            onChanged: _repairingId != null
                                ? null
                                : (accountId) {
                                    if (accountId != null) _repair(transfer.id, accountId);
                                  },
                          ),
                      ],
                    ),
                  ),
              ],
              if (_result.skipped > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_result.skipped} other transaction(s) could not be '
                    'interpreted and were left out.',
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _repairingId != null ? null : () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
