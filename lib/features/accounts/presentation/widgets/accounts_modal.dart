import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/double_extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/list_dialog.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/accounts_notifier.dart';
import '../widgets/account_card.dart';
import '../widgets/add_account_modal.dart';
import '../widgets/recalculate_balances_action.dart';

class AccountsModal extends ConsumerStatefulWidget {
  const AccountsModal({super.key});

  @override
  ConsumerState<AccountsModal> createState() => _AccountsModalState();
}

class _AccountsModalState extends ConsumerState<AccountsModal> {
  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsNotifierProvider);
    final isMobile = context.isMobile;

    return ListDialog(
      title: 'All Accounts',
      body: accountsState.when(
        initial: () => const LoadingIndicator(),
        loading: () => const LoadingIndicator(),
        error: (failure) => ErrorView(
          message: failure.message,
          onRetry: () => ref.read(accountsNotifierProvider.notifier).refresh(),
        ),
        loaded: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              title: 'No Accounts Yet',
              message:
                  'Create your first account to start tracking your finances',
              iconData: Icons.account_balance_wallet_outlined,
              actionLabel: 'Add Account',
              action: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => const AddAccountModal(),
                );
              },
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < accounts.length - 1 ? 8 : 0,
                ),
                child: AccountCard(
                  account: account,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push(
                      RouteConstants.accountDetail
                          .replaceAll(':id', account.id),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      actions: [
        TextButton.icon(
          onPressed: () => recalculateBalancesWithConfirmation(context, ref),
          icon: const Icon(Icons.sync),
          label: const Text('Sync balances'),
        ),
        FilledButton.icon(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (context) => const AddAccountModal(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Account'),
        ),
      ],
    );
  }
}
